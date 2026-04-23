defmodule Mix.Tasks.CmsGen.IntegrationProvider do
  @shortdoc "Generates an OAuth integration provider"

  @moduledoc """
  Generates an OAuth provider module for the integrations system.

      $ mix cms_gen.integration_provider GitHub github
      $ mix cms_gen.integration_provider Google google
      $ mix cms_gen.integration_provider Facebook facebook
      $ mix cms_gen.integration_provider QuickBooks quickbooks

  The first argument is the human-readable provider name (e.g., "GitHub").
  The second argument is the provider atom key (e.g., "github").

  This generator requires `cms_gen.integrations` to have been run first.

  ## Generated files

    * `lib/app/integrations/providers/<provider>.ex` — Provider module

  ## Known providers

  For GitHub, Google, Facebook, and QuickBooks, specialized templates
  are used with pre-configured OAuth scopes and endpoints. For unknown
  providers, a generic template is generated.
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator

  @known_providers ~w(github google facebook quickbooks codemyspec)

  @impl true
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.integration_provider must be invoked from within your OTP application root directory"
      )
    end

    case args do
      [display_name, provider_key] ->
        generate(display_name, provider_key)

      _ ->
        Mix.raise("""
        mix cms_gen.integration_provider expects exactly 2 arguments:

            mix cms_gen.integration_provider DisplayName provider_key

        Examples:

            mix cms_gen.integration_provider GitHub github
            mix cms_gen.integration_provider Google google
        """)
    end
  end

  defp generate(display_name, provider_key) do
    app = Mix.Phoenix.otp_app()

    # Verify integrations generator has been run
    Generator.ensure_dep_ran!("mix cms_gen.integrations", [
      Path.join(["lib", to_string(app), "integrations", "providers", "behaviour.ex"])
    ])

    binding =
      Generator.binding() ++
        [
          provider_key: provider_key,
          provider_atom: String.to_atom(provider_key),
          provider_module: Macro.camelize(provider_key),
          display_name: display_name
        ]

    lib_path = Generator.lib_path("")

    # Choose template based on known providers
    template =
      if provider_key in @known_providers do
        "#{provider_key}.ex"
      else
        "provider.ex"
      end

    target = Path.join([lib_path, "integrations", "providers", "#{provider_key}.ex"])

    files = [
      {:eex, template, target}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.integration_provider", binding, files)

    Generator.print_shell_instructions("""
    #{display_name} provider generated!

    1. Add :#{provider_key} to your integration_providers config in config/config.exs:

        config :#{app}, :integration_providers, [:#{provider_key}]

    2. Configure the OAuth credentials in config/runtime.exs:

        config :#{app},
          #{provider_key}_client_id: System.get_env("#{String.upcase(provider_key)}_CLIENT_ID"),
          #{provider_key}_client_secret: System.get_env("#{String.upcase(provider_key)}_CLIENT_SECRET")

    3. Add the provider to your oauth_providers map:

        config :#{app}, :oauth_providers, %{
          #{provider_key}: #{binding[:app_module]}.Integrations.Providers.#{binding[:provider_module]}
        }
    """)
  end
end
