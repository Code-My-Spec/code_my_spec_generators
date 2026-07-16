defmodule Mix.Tasks.CmsGen.Content do
  @shortdoc "Generates the published content context for deploying content"

  @moduledoc """
  Generates the Content context for serving published content (blog posts, pages,
  landing pages, and documentation) to public and authenticated viewers.

      $ mix cms_gen.content

  This is the single-tenant, production-facing content system. Access control is
  based on authentication (Scope vs nil) rather than multi-tenancy — there is no
  account_id/project_id filtering. It is distinct from the multi-tenant
  ContentAdmin layer and is the target of the publishing/sync flow.

  This generator requires `phx.gen.auth` to have been run first (it depends on the
  generated `Users.Scope`).

  ## Generated files

  ### Schemas
    * `lib/app/content/content.ex` — Content schema (slug, content_type, processed HTML, SEO/OG metadata)
    * `lib/app/content/tag.ex` — Tag schema (global, single-tenant)
    * `lib/app/content/content_tag.ex` — Join schema for content/tags

  ### Repositories
    * `lib/app/content/content_repository.ex` — Published content queries (scope-aware)
    * `lib/app/content/tag_repository.ex` — Tag upsert/lookup

  ### Context
    * `lib/app/content.ex` — Content context with sync_content/1 publishing flow

  ### Pull flow
    * `lib/app/content/pull.ex` — manifest fetch, hash verification, atomic replace
    * `lib/app/content/pull_client.ex` — Req client for manifest/blob GETs
    * `lib/app/content/s3_client.ex` — ExAws S3 put/get (needs :ex_aws + :ex_aws_s3)
    * `lib/app/content/ex_aws_req_client.ex` — Req-backed ExAws HTTP client

  ### Web
    * `lib/app_web/controllers/content_sync_controller.ex` — POST /sync (push) and
      POST /pull (trigger), both deploy-key authenticated

  ### Migrations
    * `priv/repo/migrations/*_create_content_tables.exs` — contents + tags + content_tags

  The `/api/content` router scope is injected automatically, and injection is
  idempotent — re-running the generator will not duplicate it.
  """

  use Mix.Task

  alias CodeMySpecGenerators.{Generator, Injector}

  @impl true
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.content must be invoked from within your OTP application root directory"
      )
    end

    # Verify phx.gen.auth has been run (Content queries depend on Users.Scope)
    app = Mix.Phoenix.otp_app()
    scope_file = Path.join(["lib", to_string(app), "users", "scope.ex"])

    Generator.ensure_dep_ran!("mix phx.gen.auth", [scope_file])

    binding = Generator.binding()
    timestamp = Generator.migration_timestamp()

    lib_path = Generator.lib_path("")
    web_lib_path = Generator.web_lib_path("")

    files = [
      # Schemas
      {:eex, "content/content.ex", Path.join([lib_path, "content", "content.ex"])},
      {:eex, "content/tag.ex", Path.join([lib_path, "content", "tag.ex"])},
      {:eex, "content/content_tag.ex", Path.join([lib_path, "content", "content_tag.ex"])},
      # Repositories
      {:eex, "content/content_repository.ex",
       Path.join([lib_path, "content", "content_repository.ex"])},
      {:eex, "content/tag_repository.ex",
       Path.join([lib_path, "content", "tag_repository.ex"])},
      # Context
      {:eex, "content.ex", Path.join([lib_path, "content.ex"])},
      # Pull flow
      {:eex, "content/pull.ex", Path.join([lib_path, "content", "pull.ex"])},
      {:eex, "content/pull_client.ex", Path.join([lib_path, "content", "pull_client.ex"])},
      {:eex, "content/s3_client.ex", Path.join([lib_path, "content", "s3_client.ex"])},
      {:eex, "content/ex_aws_req_client.ex",
       Path.join([lib_path, "content", "ex_aws_req_client.ex"])},
      # Web — the endpoint the publishing flow calls (POST /sync and POST /pull)
      {:eex, "content_sync_controller.ex",
       Path.join([web_lib_path, "controllers", "content_sync_controller.ex"])},
      # Migration (contents, tags, content_tags)
      {:eex, "migration.exs",
       Path.join(["priv", "repo", "migrations", "#{timestamp}_create_content_tables.exs"])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.content", binding, files)

    router_path = Path.join([web_lib_path, "router.ex"])
    inject_content_routes(router_path, binding)

    Generator.print_shell_instructions("""
    Content generator complete!

    1. Run the migration:

        $ mix ecto.migrate

    2. The publishing endpoints are generated and routed for you:

        POST /api/content/sync — the publishing server pushes the corpus
        POST /api/content/pull — the publishing server sends a manifest_url trigger

       Both authenticate with `Authorization: Bearer <DEPLOY_KEY>`. Configure the
       key in config/runtime.exs:

        config :#{app}, :deploy_key, System.get_env("DEPLOY_KEY")

       And make pulls run synchronously in tests, so they share the ExUnit
       sandbox connection (config/test.exs):

        config :#{app}, content_pull_async: false

    3. Read published content from your LiveViews/controllers:

        #{binding[:app_module]}.Content.list_published_content(scope_or_nil, :blog)
        #{binding[:app_module]}.Content.get_content_by_slug(scope_or_nil, slug, :blog)

       Pass a %Scope{} for authenticated viewers (sees protected content) or nil
       for anonymous visitors (public content only).

    4. Content.S3Client / Content.ExAwsReqClient need these deps in mix.exs:

        {:ex_aws, "~> 2.5"},
        {:ex_aws_s3, "~> 2.5"}

       They are only used to read/write an S3 bucket directly. The pull flow
       itself fetches over plain HTTP via Content.PullClient and does not need
       them — delete both modules if this app never touches S3.
    """)
  end

  # Injects the /api/content scope into the router. Idempotent: keyed on the
  # :pull action, so re-running is a no-op. If the app already routes :sync
  # without :pull (a hand-wired endpoint predating this generator), we do not
  # inject a second scope that would shadow the existing one — we print the one
  # missing line instead.
  defp inject_content_routes(router_path, binding) do
    routes = """
      scope "/api/content", #{binding[:web_module]} do
        pipe_through :api

        post "/sync", ContentSyncController, :sync
        post "/pull", ContentSyncController, :pull
      end
    """

    cond do
      not File.exists?(router_path) ->
        print_manual_routes(router_path, routes)

      String.contains?(File.read!(router_path), "ContentSyncController, :pull") ->
        Mix.shell().info([:green, "* unchanged ", :reset, router_path, " (routes already present)"])

      String.contains?(File.read!(router_path), "ContentSyncController, :sync") ->
        Mix.shell().info([
          :yellow,
          "* skipped ",
          :reset,
          router_path,
          " already has an /api/content sync route. Add the pull route to that scope:\n\n" <>
            "    post \"/pull\", ContentSyncController, :pull\n"
        ])

      true ->
        case Injector.inject_into_file(
               router_path,
               routes,
               &Injector.inject_before_final_end(&1, routes)
             ) do
          :ok -> Mix.shell().info([:green, "* injecting ", :reset, router_path])
          _ -> :ok
        end
    end
  end

  defp print_manual_routes(router_path, routes) do
    Mix.shell().error("""
    Could not find #{router_path}. Add these routes to your router manually:

    #{routes}
    """)
  end
end
