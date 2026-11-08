defmodule Mix.Tasks.CmsGen.SupportWidget do
  @shortdoc "Generates the CodeMySpec support widget (chat + report a problem)"

  @moduledoc """
  Installs the shared `ClientUtils` support widget. Only the host authentication
  hook and verification route are generated; UI and transport live in the library.
  Run `mix cms_gen.support_widget`, fetch dependencies, then rebuild assets.
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator
  alias CodeMySpecGenerators.Injector

  @impl true
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.support_widget must be invoked from within your OTP application root directory"
      )
    end

    web_lib_path = Generator.web_lib_path("")

    binding =
      Generator.binding()
      |> Keyword.put(:has_user_auth, File.exists?(Path.join(web_lib_path, "user_auth.ex")))

    files = [
      {:eex, "support_widget_live.ex",
       Path.join([web_lib_path, "live", "support_widget_live.ex"])},
      {:eex, "widget_verify_controller.ex",
       Path.join([web_lib_path, "controllers", "widget_verify_controller.ex"])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.support_widget", binding, files)

    done = [
      patch_deps(),
      patch_supervision_tree(binding),
      patch_layout(binding),
      patch_router(binding),
      patch_runtime_config(binding),
      patch_assets()
    ]

    Generator.print_shell_instructions(instructions(binding, done))
  end

  # Keep installation wiring idempotent; the dependency owns the widget behavior.
  defp patch_deps do
    patch_file(
      "mix.exs",
      ~s(ref: "0648f3ed1092e1346345d1adbb1d1e37eaf729ed"),
      fn source ->
        if String.contains?(source, "{:client_utils,") do
          String.replace(
            source,
            ~r/\{:client_utils,[^}]+\}/,
            ~s({:client_utils, github: "Code-My-Spec/client_utils", ref: "0648f3ed1092e1346345d1adbb1d1e37eaf729ed"})
          )
        else
          String.replace(
            source,
            ~r/(defp deps do\s*\[)/,
            ~s(\\1
      {:client_utils, github: "Code-My-Spec/client_utils", ref: "0648f3ed1092e1346345d1adbb1d1e37eaf729ed"},)
          )
        end
      end,
      "configured client_utils from Git",
      "add client_utils as a Git dependency"
    )
  end

  defp patch_supervision_tree(binding) do
    patch_file(
      application_file(binding),
      "{ClientUtils.Widget,",
      fn source ->
        String.replace(
          source,
          ~r/(\n(\s*)\{Phoenix\.PubSub,)/,
          "\n\\2{ClientUtils.Widget, otp_app: :#{binding[:app]}},\\1",
          global: false
        )
      end,
      "added shared widget supervision",
      "add {ClientUtils.Widget, otp_app: :#{binding[:app]}} before the Endpoint"
    )
  end

  defp patch_assets do
    js =
      patch_file(
        "assets/js/app.js",
        "CmsSupportWidget",
        fn source ->
          patched =
            cond do
              Regex.match?(~r/hooks:\s*\{/, source) ->
                String.replace(
                  source,
                  ~r/hooks:\s*\{/,
                  "hooks: {CmsSupportWidget, CmsChatScroll,",
                  global: false
                )

              Regex.match?(~r/hooks:\s*[A-Za-z_$][\w$]*/, source) ->
                String.replace(
                  source,
                  ~r/hooks:\s*([A-Za-z_$][\w$]*)/,
                  "hooks: {...\\1, CmsSupportWidget, CmsChatScroll}",
                  global: false
                )

              true ->
                source
            end

          if patched == source do
            source
          else
            "import CmsSupportWidget, {CmsChatScroll} from \"../../deps/client_utils/priv/static/widget.js\"\n" <>
              patched
          end
        end,
        "registered shared widget hooks",
        "register CmsSupportWidget from client_utils in LiveSocket hooks"
      )

    css =
      patch_file(
        "assets/css/app.css",
        "deps/client_utils/lib",
        fn source ->
          source <> "\n@source \"../../deps/client_utils/lib\";\n"
        end,
        "included shared widget styles",
        "include client_utils/lib in Tailwind sources"
      )

    js <> "; " <> css
  end

  # `mix phx.new` puts the Application module under `lib/<app>/`; `mix cms.new`
  # emits it into the web namespace instead. Both are ordinary, so both are
  # looked for rather than one being assumed — assuming the stock path made
  # this report `:enoent` against a project whose supervision tree was sitting
  # one directory over.
  defp application_file(binding) do
    app = to_string(binding[:app])

    ["lib/#{app}_web/application.ex", "lib/#{app}/application.ex"]
    |> Enum.find(&File.exists?/1)
    |> Kernel.||("lib/#{app}/application.ex")
  end

  defp patch_layout(binding) do
    web_module = binding[:web_module]

    patch_file(
      Path.join(["lib", "#{binding[:app]}_web", "components", "layouts", "root.html.heex"]),
      "codemyspec-support",
      &String.replace(
        &1,
        "</body>",
        ~s|    <%= if ClientUtils.Widget.configured?(:#{binding[:app]}) do %>
      {live_render(Plug.Conn.put_private(@conn, :phoenix_live_view, nil), #{web_module}.SupportWidgetLive, id: "codemyspec-support", sticky: true)}
    <% end %>
  </body>|,
        global: false
      ),
      "rendered the widget in root.html.heex",
      "render SupportWidgetLive in root.html.heex before </body>, or the widget never appears"
    )
  end

  # No pipeline: the endpoint already parses JSON, and the route must not
  # depend on a pipeline the host app may have renamed or removed.
  defp patch_router(binding) do
    routes = """
      # CodeMySpec proves the widget by asking it to send a message. Deploy-key
      # protected in the controller; /health stays a shallow liveness probe.
      scope "/_cms", #{binding[:web_module]} do
        post "/verify/widget", WidgetVerifyController, :create
      end
    """

    patch_file(
      Path.join(["lib", "#{binding[:app]}_web", "router.ex"]),
      "WidgetVerifyController",
      &(Injector.inject_before_final_end(&1, routes) || &1),
      "routed POST /_cms/verify/widget in router.ex",
      "route POST /_cms/verify/widget to WidgetVerifyController, :create"
    )
  end

  defp patch_runtime_config(binding) do
    app = binding[:app]

    config = """

    # The support widget's socket and private installation credential path. Read at
    # runtime so one image serves every environment.
    config :#{app},
      codemyspec_server_url:
        System.get_env("CODEMYSPEC_SERVER_URL")

    config :#{app}, :codemyspec_credentials_path,
      System.get_env("CODEMYSPEC_CREDENTIALS_PATH")
    """

    patch_file(
      Path.join(["config", "runtime.exs"]),
      "codemyspec_server_url",
      &(&1 <> config),
      "configured the widget socket in runtime.exs",
      "configure :codemyspec_server_url and :codemyspec_credentials_path in runtime.exs"
    )
  end

  # Read, skip if already done, apply, and say which of those happened. An
  # unrecognised file is reported rather than guessed at: a shape this does not
  # understand is one somebody has already edited, and guessing is how a
  # generator eats someone's work.
  defp patch_file(path, marker, patch, did, todo),
    do: Generator.patch_file(path, marker, patch, did, todo)

  defp instructions(binding, done) do
    """
    Support widget generated (chat + report a problem)!

    ## Done for you

    #{Enum.map_join(done, "\n", &("  * " <> &1))}

    ## Left to you

    Run `mix deps.get`, rebuild assets, and restart the server. Screenshot capture
    ships in client_utils; consumers do not install another npm package.

    Authorize the host once as the project owner:

      mix client_utils.authorize --server https://codemyspec.com --project PROJECT_UUID --credentials /private/state/codemyspec.json

    Open the printed URL and approve the code. Set CODEMYSPEC_CREDENTIALS_PATH
    to that private file at runtime; keep it outside the repository and public assets.
    Visitors do not authorize devices. Manage installations at /oauth/installations.
    The optional inbound /_cms/verify/widget provisioning probe still uses DEPLOY_KEY.

    The widget renders unconditionally, for everyone — visitors who never
    signed up are who the most useful feedback comes from, and it gives them a
    session-derived identity of their own. #{binding[:web_module]}.SupportWidgetLive
    is what draws it.
    """
  end
end
