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

  It prints (does not edit) the dep, supervision, layout and config you must add.

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

    Generator.print_shell_instructions(instructions(binding))
  end

  defp instructions(binding) do
    app = binding[:app]
    base = binding[:app_module]
    web_module = binding[:web_module]

    """
    Support widget generated (chat + report a problem)!

    ## Setup

    1. Add slipstream to your deps in mix.exs:

        {:slipstream, "~> 1.1"},

    2. Add the registry + supervisor to your supervision tree
       (lib/#{app}/application.ex), before the Endpoint:

        {Registry, keys: :unique, name: #{base}.CodeMySpec.WidgetRegistry},
        {DynamicSupervisor, strategy: :one_for_one, name: #{base}.CodeMySpec.WidgetSupervisor},

    3. Render the widget for logged-in users in
       lib/#{app}_web/components/layouts/root.html.heex, before </body>:

        <%= if @current_scope && @current_scope.user do %>
          {live_render(@conn, #{web_module}.SupportWidgetLive, id: "codemyspec-support", sticky: true)}
        <% end %>

    4. Configure the widget socket URL (reuses your existing :deploy_key),
       e.g. in runtime.exs:

        config :#{app},
          codemyspec_widget_url:
            System.get_env("CODEMYSPEC_WIDGET_URL") || "wss://codemyspec.com/widget"

        config :#{app}, :deploy_key, System.get_env("DEPLOY_KEY")

    5. (Optional) Enable "Report a problem" screenshots — the capture button
       dynamically imports html-to-image:

        cd assets && npm install html-to-image --prefix .

       Without it, reports still submit; only screenshot capture is a no-op.

    6. Run `mix deps.get`, then restart the server.
    """
  end
end
