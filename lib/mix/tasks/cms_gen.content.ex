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

  ### Migrations
    * `priv/repo/migrations/*_create_content_tables.exs` — contents + tags + content_tags
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator

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
      # Migration (contents, tags, content_tags)
      {:eex, "migration.exs",
       Path.join(["priv", "repo", "migrations", "#{timestamp}_create_content_tables.exs"])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.content", binding, files)

    Generator.print_shell_instructions("""
    Content generator complete!

    1. Run the migration:

        $ mix ecto.migrate

    2. The Content context exposes a publishing/sync entrypoint:

        #{binding[:app_module]}.Content.sync_content(content_list)

       Wire this up to your content sync endpoint (e.g. POST /api/content/sync)
       so your publishing flow can push processed content into this app.

    3. Read published content from your LiveViews/controllers:

        #{binding[:app_module]}.Content.list_published_content(scope_or_nil, :blog)
        #{binding[:app_module]}.Content.get_content_by_slug(scope_or_nil, slug, :blog)

       Pass a %Scope{} for authenticated viewers (sees protected content) or nil
       for anonymous visitors (public content only).
    """)
  end
end
