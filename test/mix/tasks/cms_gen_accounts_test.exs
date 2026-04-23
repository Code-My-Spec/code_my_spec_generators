defmodule Mix.Tasks.CmsGen.AccountsTest do
  use ExUnit.Case, async: false

  import CodeMySpecGenerators.GeneratorTestHelpers

  @moduletag :generator

  describe "cms_gen.accounts" do
    test "generates all expected account files" do
      # Verify the templates exist
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "account.ex"))
      assert_file(Path.join(templates_dir, "member.ex"))
      assert_file(Path.join(templates_dir, "accounts_repository.ex"))
      assert_file(Path.join(templates_dir, "members_repository.ex"))
      assert_file(Path.join(templates_dir, "accounts.ex"))
      assert_file(Path.join(templates_dir, "authorization.ex"))
      assert_file(Path.join(templates_dir, "migration.exs"))
    end

    test "generates all expected invitation files" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "invitation.ex"))
      assert_file(Path.join(templates_dir, "invitation_repository.ex"))
      assert_file(Path.join(templates_dir, "invitation_notifier.ex"))
    end

    test "generates all expected LiveView files" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "account_live/index.ex"))
      assert_file(Path.join(templates_dir, "account_live/manage.ex"))
      assert_file(Path.join(templates_dir, "account_live/members.ex"))
      assert_file(Path.join(templates_dir, "account_live/picker.ex"))
      assert_file(Path.join(templates_dir, "account_live/form.ex"))
      assert_file(Path.join(templates_dir, "account_live/invitations.ex"))
      assert_file(Path.join(templates_dir, "account_live/components/navigation.ex"))
      assert_file(Path.join(templates_dir, "account_live/components/members_list.ex"))
      assert_file(Path.join(templates_dir, "account_live/components/accounts_breadcrumb.ex"))
      assert_file(Path.join(templates_dir, "invitations_live/accept.ex"))
      assert_file(Path.join(templates_dir, "invitations_live/form.ex"))
      assert_file(Path.join(templates_dir, "invitations_live/components/pending_invitations.ex"))
    end

    test "account template contains EEx bindings" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "account.ex"), [
        "<%= app_module %>",
        "Accounts.Account",
        ":binary_id"
      ])
    end

    test "member template contains role hierarchy" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "member.ex"), [
        "<%= app_module %>",
        ":owner",
        ":admin",
        ":member",
        "has_role?"
      ])
    end

    test "invitation template uses SHA256 token hashing" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "invitation.ex"), [
        "@hash_algorithm :sha256",
        "@rand_size 32",
        "build_token",
        "token_hash",
        ":crypto.strong_rand_bytes",
        "Base.url_encode64"
      ])
    end

    test "migration includes accounts, members, and invitations tables" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "migration.exs"), [
        "create table(:accounts",
        ":binary_id",
        "create table(:members",
        "create table(:invitations",
        ":token_hash",
        "unique_index(:members, [:user_id, :account_id])"
      ])
    end

    test "accounts context includes PubSub and invitation functions" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.accounts")

      assert_file(Path.join(templates_dir, "accounts.ex"), [
        "subscribe_account",
        "subscribe_member",
        "subscribe_invitations",
        "invite_user",
        "accept_invitation",
        "list_pending_invitations",
        "cancel_invitation",
        "<%= pubsub %>"
      ])
    end
  end
end
