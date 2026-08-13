defmodule Mix.Tasks.CmsGen.SupportWidget do
  @shortdoc "Generates the CodeMySpec support widget (chat + report a problem)"

  @moduledoc """
  Generates an always-on support widget for a host app's logged-in users. One
  widget, two clear intents:

    * **Chat** — a live conversation with a CodeMySpec operator.
    * **Report a problem** — file an issue (title / description / severity) that
      lands in the project's CodeMySpec issue queue.

      $ mix cms_gen.support_widget

  Both intents ride ONE connection: per logged-in user, the host app's **server**
  opens a Slipstream connection to CodeMySpec authenticated by the project
  **deploy key** (the key never reaches the browser). Chat relays
  `send_message`/`new_message`; "Report a problem" pushes a `submit_feedback`
  event on the same `conversation:<user_id>` topic, which CodeMySpec files as an
  issue. No OAuth, no second transport.

  This supersedes `cms_gen.feedback_widget` (feedback-only, OAuth/REST) — the
  support widget does everything that did, plus chat, over the deploy-key socket.

  ## Generated files

    * `lib/<app>/code_my_spec/widget_client.ex` — per-user Slipstream client
    * `lib/<app>/code_my_spec/widget.ex` — registry/supervisor interface
    * `lib/<app>_web/live/support_widget_live.ex` — the sticky nested LiveView

  It also edits the four things the widget needs to work: the `slipstream`
  dependency, the registry and supervisor in the supervision tree, the
  `live_render` in the root layout, and the socket URL and deploy key in
  runtime config. Each is skipped if already present and reported either way.

  ## Assumptions

  `phx.gen.auth` conventions: `<Base>Web.UserAuth` provides an
  `on_mount {_, :mount_current_scope}` assigning `current_scope.user`, and the
  app runs `<Base>.PubSub`. The deploy key is read from
  `Application.get_env(:<app>, :deploy_key)` — the same key content sync uses.
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator

  @impl true
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.support_widget must be invoked from within your OTP application root directory"
      )
    end

    binding = Generator.binding()
    lib_path = Generator.lib_path("")
    web_lib_path = Generator.web_lib_path("")

    files = [
      {:eex, "widget_client.ex", Path.join([lib_path, "code_my_spec", "widget_client.ex"])},
      {:eex, "widget.ex", Path.join([lib_path, "code_my_spec", "widget.ex"])},
      {:eex, "support_widget_live.ex",
       Path.join([web_lib_path, "live", "support_widget_live.ex"])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.support_widget", binding, files)

    done = [
      patch_deps(),
      patch_supervision_tree(binding),
      patch_layout(binding),
      patch_runtime_config(binding)
    ]

    Generator.print_shell_instructions(instructions(binding, done))
  end

  # The edits below used to be steps 1 to 4 of the printed instructions, which
  # meant a generated project carried a widget that could not compile and, once
  # that was fixed by hand, was never rendered or supervised. `use Slipstream`
  # in code whose project does not depend on slipstream is the loud half:
  #
  #   ** (CompileError) cannot compile module <App>.CodeMySpec.WidgetClient
  #       expanding macro: Kernel.use/1
  #
  # The quiet half is worse — a project that compiles, deploys, and has no
  # widget on the page, with nothing anywhere saying so. `agent_tasks` drives
  # this chain unattended and never read the instructions.
  #
  # Each patch reports what it did, because silently editing a file the
  # operator wrote is worse than telling them, and each leaves an
  # already-patched file alone so re-running the generator is safe.

  defp patch_deps do
    patch_file(
      "mix.exs",
      "slipstream",
      &String.replace(
        &1,
        ~r/(\n\s*)\{:phoenix, "~> [^}]+\},/,
        "\\0\\1{:slipstream, \"~> 1.1\"},",
        global: false
      ),
      "added {:slipstream, \"~> 1.1\"} to mix.exs — `use Slipstream` needs it",
      "add {:slipstream, \"~> 1.1\"} to your deps, or the widget client will not compile"
    )
  end

  defp patch_supervision_tree(binding) do
    base = binding[:app_module]

    patch_file(
      application_file(binding),
      "WidgetRegistry",
      &String.replace(
        &1,
        ~r/(\n(\s*)\{Phoenix\.PubSub,)/,
        "\n\\2{Registry, keys: :unique, name: #{base}.CodeMySpec.WidgetRegistry},\n\\2{DynamicSupervisor, strategy: :one_for_one, name: #{base}.CodeMySpec.WidgetSupervisor},\\1",
        global: false
      ),
      "added the widget registry and supervisor to application.ex",
      "add the widget Registry and DynamicSupervisor to your supervision tree before the Endpoint"
    )
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
        ~s|    {live_render(@conn, #{web_module}.SupportWidgetLive, id: "codemyspec-support", sticky: true)}\n  </body>|,
        global: false
      ),
      "rendered the widget in root.html.heex",
      "render SupportWidgetLive in root.html.heex before </body>, or the widget never appears"
    )
  end

  defp patch_runtime_config(binding) do
    app = binding[:app]

    config = """

    # The support widget's socket, and the key it authenticates with. Read at
    # runtime so one image serves every environment.
    config :#{app},
      codemyspec_widget_url:
        System.get_env("CODEMYSPEC_WIDGET_URL") || "wss://codemyspec.com/widget"

    config :#{app}, :deploy_key, System.get_env("DEPLOY_KEY")
    """

    patch_file(
      Path.join(["config", "runtime.exs"]),
      "codemyspec_widget_url",
      &(&1 <> config),
      "configured the widget socket in runtime.exs",
      "configure :codemyspec_widget_url and :deploy_key in runtime.exs"
    )
  end

  # Read, skip if already done, apply, and say which of those happened. An
  # unrecognised file is reported rather than guessed at: a shape this does not
  # understand is one somebody has already edited, and guessing is how a
  # generator eats someone's work.
  defp patch_file(path, marker, patch, did, todo) do
    case File.read(path) do
      {:error, reason} ->
        "COULD NOT READ #{path} (#{inspect(reason)}) — #{todo}"

      {:ok, contents} ->
        apply_patch(String.contains?(contents, marker), contents, path, patch, did, todo)
    end
  end

  defp apply_patch(true, _contents, path, _patch, _did, _todo),
    do: "#{path} already carries it — left alone"

  defp apply_patch(false, contents, path, patch, did, todo) do
    patched = patch.(contents)

    case patched == contents do
      true -> "COULD NOT PATCH #{path} — its shape is not the generated one. Please #{todo}"
      false -> write_patch(File.write(path, patched), path, did, todo)
    end
  end

  defp write_patch(:ok, _path, did, _todo), do: did

  defp write_patch({:error, reason}, path, _did, todo),
    do: "COULD NOT WRITE #{path} (#{inspect(reason)}) — #{todo}"

  defp instructions(binding, done) do
    """
    Support widget generated (chat + report a problem)!

    ## Done for you

    #{Enum.map_join(done, "\n", &("  * " <> &1))}

    ## Left to you

    1. Run `mix deps.get`, then restart the server.

    2. (Optional) Enable "Report a problem" screenshots — the capture button
       dynamically imports html-to-image:

        cd assets && npm install html-to-image --prefix #{Path.join("assets", ".")}

       Without it, reports still submit; only screenshot capture is a no-op.

    The widget renders unconditionally, for everyone — visitors who never
    signed up are who the most useful feedback comes from, and it gives them a
    session-derived identity of their own. #{binding[:web_module]}.SupportWidgetLive
    is what draws it.
    """
  end
end
