defmodule Mix.Tasks.CmsGen.Integrations do
  @shortdoc "Generates OAuth integrations scaffolding"

  @moduledoc """
  Generates the integrations context with OAuth flow support,
  encrypted token storage, and provider behaviour.

      $ mix cms_gen.integrations

  This generator requires `phx.gen.auth` to have been run first.

  ## Generated files

    * `lib/app/integrations/integration.ex` — Integration schema
    * `lib/app/integrations/integration_repository.ex` — Data access with upsert
    * `lib/app/integrations/o_auth_state_store.ex` — ETS-backed OAuth state
    * `lib/app/integrations/providers/behaviour.ex` — Provider behaviour
    * `lib/app/integrations.ex` — Integrations context
    * `lib/app/encrypted/binary.ex` — Cloak.Ecto encrypted type
    * `lib/app/vault.ex` — Cloak vault
    * `lib/app_web/controllers/integrations_controller.ex` — OAuth controller
    * `lib/app_web/live/integration_live/index.ex` — Integrations listing
    * `priv/repo/migrations/*_create_integrations_tables.exs` — Migration

  ## Dependencies

  You will need to add the following dependencies to your mix.exs:

    * `{:assent, "~> 0.3"}` — OAuth strategies
    * `{:cloak_ecto, "~> 1.3"}` — Encrypted Ecto types
    * `{:cloak, "~> 1.1"}` — Encryption vault
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator

  @impl true
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.integrations must be invoked from within your OTP application root directory"
      )
    end

    app = Mix.Phoenix.otp_app()

    # Verify phx.gen.auth has been run
    Generator.ensure_dep_ran!("mix phx.gen.auth", [
      Path.join(["lib", to_string(app), "users", "scope.ex"])
    ])

    binding = Generator.binding()
    timestamp = Generator.migration_timestamp()

    lib_path = Generator.lib_path("")
    web_lib_path = Generator.web_lib_path("")

    files = [
      # Schema & repos
      {:eex, "integration.ex", Path.join([lib_path, "integrations", "integration.ex"])},
      {:eex, "integration_repository.ex",
       Path.join([lib_path, "integrations", "integration_repository.ex"])},
      {:eex, "o_auth_state_store.ex",
       Path.join([lib_path, "integrations", "o_auth_state_store.ex"])},
      {:eex, "provider_behaviour.ex",
       Path.join([lib_path, "integrations", "providers", "behaviour.ex"])},
      # Context
      {:eex, "integrations.ex", Path.join([lib_path, "integrations.ex"])},
      # Encryption
      {:eex, "encrypted_binary.ex", Path.join([lib_path, "encrypted", "binary.ex"])},
      {:eex, "vault.ex", Path.join([lib_path, "vault.ex"])},
      # Controller
      {:eex, "integrations_controller.ex",
       Path.join([web_lib_path, "controllers", "integrations_controller.ex"])},
      # LiveViews
      {:eex, "integration_live/index.ex",
       Path.join([web_lib_path, "live", "integration_live", "index.ex"])},
      # Migration
      {:eex, "migration.exs",
       Path.join(["priv", "repo", "migrations", "#{timestamp}_create_integrations_tables.exs"])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.integrations", binding, files)

    Generator.print_shell_instructions("""
    Integrations generator complete!

    1. Add the following dependencies to your mix.exs deps:

        {:assent, "~> 0.3"},
        {:cloak_ecto, "~> 1.3"},
        {:cloak, "~> 1.1"}

       Then run:

        $ mix deps.get

    2. Add #{binding[:app_module]}.Integrations.OAuthStateStore to your Application
       supervision tree (before the Endpoint):

        #{binding[:app_module]}.Integrations.OAuthStateStore,

    3. Configure your Cloak vault in config/config.exs:

        config :#{app}, #{binding[:app_module]}.Vault,
          ciphers: [
            default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!("your-32-byte-key-base64")}
          ]

    4. Run the migration:

        $ mix ecto.migrate

    5. Add the OAuth controller routes to your router:

        scope "/integrations/oauth", #{binding[:web_module]} do
          pipe_through [:browser, :require_authenticated_user]
          get "/:provider", IntegrationsController, :request
          get "/callback/:provider", IntegrationsController, :callback
        end

    6. Add the LiveView route to your authenticated live_session:

        live "/integrations", IntegrationLive.Index, :index
    """)
  end
end
