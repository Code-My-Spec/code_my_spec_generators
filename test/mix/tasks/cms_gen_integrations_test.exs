defmodule Mix.Tasks.CmsGen.IntegrationsTest do
  use ExUnit.Case, async: false

  import CodeMySpecGenerators.GeneratorTestHelpers

  @moduletag :generator

  describe "cms_gen.integrations" do
    test "generates all expected integration files" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integration.ex"))
      assert_file(Path.join(templates_dir, "integration_repository.ex"))
      assert_file(Path.join(templates_dir, "integrations.ex"))
      assert_file(Path.join(templates_dir, "o_auth_state_store.ex"))
      assert_file(Path.join(templates_dir, "provider_behaviour.ex"))
      assert_file(Path.join(templates_dir, "encrypted_binary.ex"))
      assert_file(Path.join(templates_dir, "vault.ex"))
      assert_file(Path.join(templates_dir, "integrations_controller.ex"))
      assert_file(Path.join(templates_dir, "migration.exs"))
    end

    test "generates integration LiveView" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integration_live/index.ex"))
    end

    test "integration template uses encrypted tokens" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integration.ex"), [
        "Encrypted.Binary",
        ":access_token",
        ":refresh_token",
        "expired?",
        "has_refresh_token?"
      ])
    end

    test "OAuth state store uses ETS" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "o_auth_state_store.ex"), [
        "GenServer",
        ":oauth_state_store",
        "@ttl_seconds 300",
        ":ets.insert",
        ":ets.lookup",
        "schedule_cleanup"
      ])
    end

    test "provider behaviour defines required callbacks" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "provider_behaviour.ex"), [
        "@callback config(redirect_uri :: String.t())",
        "@callback strategy()",
        "@callback normalize_user",
        "@optional_callbacks"
      ])
    end

    test "integrations context includes OAuth flow" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integrations.ex"), [
        "authorize_url",
        "handle_callback",
        "upsert_integration",
        "list_providers"
      ])
    end

    test "migration creates integrations table with unique index" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "migration.exs"), [
        "create table(:integrations",
        ":access_token, :binary",
        "unique_index(:integrations, [:user_id, :provider])"
      ])
    end

    test "controller handles OAuth request and callback" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integrations_controller.ex"), [
        "def request(conn",
        "def callback(conn",
        "def delete(conn",
        "OAuthStateStore"
      ])
    end

    test "context surfaces update_integration delegate for token refresh" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integrations.ex"), [
        "defdelegate update_integration(scope, provider, attrs), to: IntegrationRepository",
        "@moduledoc"
      ])
    end

    test "context threads redirect_uri instead of reaching into the endpoint" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      content = File.read!(Path.join(templates_dir, "integrations.ex"))
      # The context must not call into the endpoint (only prose may mention it).
      refute String.contains?(content, "<%= endpoint %>")
      refute String.contains?(content, ".url()")
      assert String.contains?(content, "def authorize_url(provider, redirect_uri")
      assert String.contains?(content, "def handle_callback(%Scope{} = scope, provider, redirect_uri")
    end

    test "controller builds the redirect_uri in the web layer" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.integrations")

      assert_file(Path.join(templates_dir, "integrations_controller.ex"), [
        "defp oauth_redirect_uri(provider_str)",
        ".url() <> \"/integrations/oauth/callback/",
        "Integrations.authorize_url(provider, oauth_redirect_uri(provider_str))"
      ])
    end
  end
end
