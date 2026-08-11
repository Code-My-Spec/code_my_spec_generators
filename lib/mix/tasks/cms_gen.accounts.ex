defmodule Mix.Tasks.CmsGen.Accounts do
  @shortdoc "Generates accounts, members, and invitations scaffolding"

  @moduledoc """
  Generates the accounts context with Account, Member, and Invitation schemas,
  repositories, authorization, email notifications, and LiveView pages.

      $ mix cms_gen.accounts

  This generator requires `phx.gen.auth` to have been run first.

  ## Generated files

  ### Accounts & Members
    * `lib/app/accounts/account.ex` — Account schema (UUID pk, name, slug, type)
    * `lib/app/accounts/member.ex` — Member schema (role-based, user+account FKs)
    * `lib/app/accounts/accounts_repository.ex` — Account CRUD operations
    * `lib/app/accounts/members_repository.ex` — Member management
    * `lib/app/accounts.ex` — Accounts context with PubSub
    * `lib/app/authorization.ex` — Role-based authorization

  ### Invitations
    * `lib/app/accounts/invitation.ex` — Invitation schema with SHA256 token hashing
    * `lib/app/accounts/invitation_repository.ex` — Invitation data access
    * `lib/app/accounts/invitation_notifier.ex` — Swoosh email templates

  ### LiveViews
    * `lib/app_web/live/account_live/index.ex` — Account listing
    * `lib/app_web/live/account_live/manage.ex` — Account editing
    * `lib/app_web/live/account_live/members.ex` — Member management
    * `lib/app_web/live/account_live/picker.ex` — Account selection
    * `lib/app_web/live/account_live/form.ex` — Account form
    * `lib/app_web/live/account_live/invitations.ex` — Invitations tab
    * `lib/app_web/live/account_live/components/navigation.ex` — Tab navigation
    * `lib/app_web/live/account_live/components/members_list.ex` — Member table
    * `lib/app_web/live/account_live/components/accounts_breadcrumb.ex` — Breadcrumb
    * `lib/app_web/live/invitations_live/accept.ex` — Public acceptance page
    * `lib/app_web/live/invitations_live/form.ex` — Invite form component
    * `lib/app_web/live/invitations_live/components/pending_invitations.ex` — Pending list

  ### Migrations
    * `priv/repo/migrations/*_create_accounts_tables.exs` — Accounts + members + invitations
  """

  use Mix.Task

  alias CodeMySpecGenerators.Generator

  @impl true
  def run(_args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix cms_gen.accounts must be invoked from within your OTP application root directory"
      )
    end

    # Verify phx.gen.auth has been run
    app = Mix.Phoenix.otp_app()
    scope_file = Path.join(["lib", to_string(app), "users", "scope.ex"])

    Generator.ensure_dep_ran!("mix phx.gen.auth", [
      scope_file
    ])

    binding = Generator.binding()
    timestamp = Generator.migration_timestamp()

    lib_path = Generator.lib_path("")
    web_lib_path = Generator.web_lib_path("")

    files = [
      # Schemas & repos — Accounts
      {:eex, "account.ex", Path.join([lib_path, "accounts", "account.ex"])},
      {:eex, "member.ex", Path.join([lib_path, "accounts", "member.ex"])},
      {:eex, "accounts_repository.ex",
       Path.join([lib_path, "accounts", "accounts_repository.ex"])},
      {:eex, "members_repository.ex", Path.join([lib_path, "accounts", "members_repository.ex"])},
      # Schemas & repos — Invitations
      {:eex, "invitation.ex", Path.join([lib_path, "accounts", "invitation.ex"])},
      {:eex, "invitation_repository.ex",
       Path.join([lib_path, "accounts", "invitation_repository.ex"])},
      {:eex, "invitation_notifier.ex",
       Path.join([lib_path, "accounts", "invitation_notifier.ex"])},
      # Context & authorization
      {:eex, "accounts.ex", Path.join([lib_path, "accounts.ex"])},
      {:eex, "authorization.ex", Path.join([lib_path, "authorization.ex"])},
      # Migration (includes accounts, members, AND invitations tables)
      {:eex, "migration.exs",
       Path.join(["priv", "repo", "migrations", "#{timestamp}_create_accounts_tables.exs"])},
      # Account LiveViews
      {:eex, "account_live/index.ex",
       Path.join([web_lib_path, "live", "account_live", "index.ex"])},
      {:eex, "account_live/manage.ex",
       Path.join([web_lib_path, "live", "account_live", "manage.ex"])},
      {:eex, "account_live/members.ex",
       Path.join([web_lib_path, "live", "account_live", "members.ex"])},
      {:eex, "account_live/picker.ex",
       Path.join([web_lib_path, "live", "account_live", "picker.ex"])},
      {:eex, "account_live/form.ex",
       Path.join([web_lib_path, "live", "account_live", "form.ex"])},
      {:eex, "account_live/invitations.ex",
       Path.join([web_lib_path, "live", "account_live", "invitations.ex"])},
      # Account Components
      {:eex, "account_live/components/navigation.ex",
       Path.join([web_lib_path, "live", "account_live", "components", "navigation.ex"])},
      {:eex, "account_live/components/members_list.ex",
       Path.join([web_lib_path, "live", "account_live", "components", "members_list.ex"])},
      {:eex, "account_live/components/accounts_breadcrumb.ex",
       Path.join([web_lib_path, "live", "account_live", "components", "accounts_breadcrumb.ex"])},
      # Invitations LiveViews
      {:eex, "invitations_live/accept.ex",
       Path.join([web_lib_path, "live", "invitations_live", "accept.ex"])},
      {:eex, "invitations_live/form.ex",
       Path.join([web_lib_path, "live", "invitations_live", "form.ex"])},
      {:eex, "invitations_live/components/pending_invitations.ex",
       Path.join([
         web_lib_path,
         "live",
         "invitations_live",
         "components",
         "pending_invitations.ex"
       ])}
    ]

    Mix.Phoenix.prompt_for_conflicts(files)
    Generator.copy_templates("priv/templates/cms_gen.accounts", binding, files)

    scope_patch = patch_scope(scope_file)

    Generator.print_shell_instructions("""
    Accounts generator complete!

    #{scope_patch}

    2. Run the migration:

        $ mix ecto.migrate

    3. Add the following routes to your router:

       In your authenticated live_session:

        live "/accounts", AccountLive.Index, :index
        live "/accounts/picker", AccountLive.Picker, :index
        live "/accounts/:id", AccountLive.Manage, :show
        live "/accounts/:id/manage", AccountLive.Manage, :show
        live "/accounts/:id/members", AccountLive.Members, :show
        live "/accounts/:id/invitations", AccountLive.Invitations, :show

       In a public (unauthenticated) scope:

        live "/invitations/accept/:token", InvitationsLive.Accept, :new

    4. Consider adding an `on_mount` hook for `:require_active_account`
       to your router's authenticated live_session if you want to enforce
       account selection before accessing protected routes.
    """)
  end

  # The generated code reads `scope.active_account_id`, so the struct has to
  # carry it. This used to be step 1 of the printed instructions, which meant
  # every generated project failed to compile until a human read them — and
  # `agent_tasks/code_generation.ex` drives this chain unattended, so it never
  # did. Four green generators, then `KeyError: key :active_account_id not
  # found`, naming a module the operator had not touched.
  #
  # Still reports what it did, because silently editing a file the operator
  # wrote is worse than telling them.
  defp patch_scope(scope_file) do
    scope_file
    |> File.read()
    |> apply_scope_patch(scope_file)
  end

  defp apply_scope_patch({:error, reason}, scope_file) do
    """
    1. COULD NOT READ #{scope_file} (#{inspect(reason)}) — add these fields to
       its defstruct by hand, or the project will not compile:

        active_account: nil,
        active_account_id: nil
    """
  end

  defp apply_scope_patch({:ok, contents}, scope_file) do
    contents
    |> String.contains?("active_account_id")
    |> write_scope_patch(contents, scope_file)
  end

  defp write_scope_patch(true, _contents, scope_file) do
    "1. #{scope_file} already carries the account fields — left alone."
  end

  defp write_scope_patch(false, contents, scope_file) do
    patched =
      String.replace(
        contents,
        ~r/defstruct user: nil/,
        "defstruct user: nil, active_account: nil, active_account_id: nil",
        global: false
      )

    patched
    |> Kernel.==(contents)
    |> save_scope_patch(patched, scope_file)
  end

  # Unrecognised shape: say so rather than write something that might not be
  # right. A defstruct this does not understand is a file somebody has already
  # edited, and guessing at it is how a generator eats someone's work.
  defp save_scope_patch(true, _patched, scope_file) do
    """
    1. COULD NOT PATCH #{scope_file} — its defstruct is not the one
       `mix phx.gen.auth` generates. Add these fields by hand, or the project
       will not compile:

        active_account: nil,
        active_account_id: nil
    """
  end

  defp save_scope_patch(false, patched, scope_file) do
    File.write!(scope_file, patched)
    "1. Added active_account and active_account_id to #{scope_file}."
  end

end
