defmodule Mix.Tasks.CmsGen.FeedbackWidget do
  @shortdoc "Generates a CodeMySpec feedback widget"

  @moduledoc """
  Generates a floating feedback widget that reports issues to CodeMySpec.

      $ mix cms_gen.feedback_widget

  This generator requires `cms_gen.integrations` to have been run first.

  ## Generated files

    * `lib/app_web/live/feedback_widget.ex` — LiveComponent (self-contained, checks own auth)
    * `lib/app/codemyspec/client.ex` — HTTP client for CodeMySpec API
    * `assets/js/screenshot.js` — Screenshot capture via html-to-image

  ## How it works

  The widget is a LiveComponent that checks its own connection status.
  If the user hasn't connected to CodeMySpec, it renders nothing.
  No on_mount hooks, no prop-drilling, no layout attr changes needed.
  Just add it to Layouts.app — current_scope is already passed there.

  ## Prerequisites

  1. Run `mix cms_gen.integrations` first
  2. Run `mix cms_gen.integration_provider CodeMySpec codemyspec`
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator

  @impl true
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.feedback_widget must be invoked from within your OTP application root directory"
      )
    end

    app = Mix.Phoenix.otp_app()

    Generator.ensure_dep_ran!("mix cms_gen.integrations", [
      Path.join(["lib", to_string(app), "integrations.ex"])
    ])

    binding = Generator.binding()
    lib_path = Generator.lib_path("")
    web_lib_path = Generator.web_lib_path("")

    files = [
      {:eex, "feedback_widget.ex", Path.join([web_lib_path, "live", "feedback_widget.ex"])},
      {:eex, "codemyspec_client.ex", Path.join([lib_path, "codemyspec", "client.ex"])},
      {:text, "screenshot.js", Path.join(["assets", "js", "screenshot.js"])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.feedback_widget", binding, files)

    Generator.print_shell_instructions("""
    Feedback widget generated!

    ## Setup

    1. Generate the CodeMySpec provider (if not already done):

        $ mix cms_gen.integration_provider CodeMySpec codemyspec

    2. Add the FeedbackWidget to your root layout (root.html.heex) inside the
       <body> tag. Do NOT add it to Layouts.app — live_component cannot render
       in dead views (controller-rendered pages) and will cause errors.

       In root.html.heex, add before the closing </body>:

        <%= if assigns[:socket] do %>
          <.live_component
            module={#{binding[:web_module]}.FeedbackWidget}
            id="codemyspec-feedback"
            current_scope={assigns[:current_scope]}
          />
        <% end %>

    3. Install html-to-image and import the screenshot module:

        $ cd assets && npm install html-to-image --prefix .

       Then add to your assets/js/app.js:

        import "./screenshot"

       Note: Phoenix uses esbuild which resolves node_modules from
       the assets directory. No global npm install needed.

    4. Add to config/config.exs:

        config :#{app}, :codemyspec_url, "https://codemyspec.com"

    5. Add to config/runtime.exs:

        config :#{app},
          codemyspec_url: System.get_env("CODEMYSPEC_URL") || "https://codemyspec.com",
          codemyspec_client_id: System.get_env("CODEMYSPEC_CLIENT_ID"),
          codemyspec_client_secret: System.get_env("CODEMYSPEC_CLIENT_SECRET")

    6. Add :codemyspec to your oauth_providers and integration_providers config:

        config :#{app}, :oauth_providers, %{
          codemyspec: #{binding[:app_module]}.Integrations.Providers.Codemyspec
        }

        config :#{app}, :integration_providers, [:codemyspec]
    """)
  end
end
