defmodule Mix.Tasks.CmsGen.IntegrationProviderTest do
  use ExUnit.Case, async: false

  import CodeMySpecGenerators.GeneratorTestHelpers

  @moduletag :generator

  describe "cms_gen.integration_provider" do
    test "GitHub provider template exists with correct patterns" do
      templates_dir =
        Application.app_dir(
          :code_my_spec_generators,
          "priv/templates/cms_gen.integration_provider"
        )

      assert_file(Path.join(templates_dir, "github.ex"), [
        "Assent.Strategy.Github",
        "github_client_id",
        "github_client_secret",
        "user:email",
        "normalize_user"
      ])
    end

    test "Google provider template exists with correct patterns" do
      templates_dir =
        Application.app_dir(
          :code_my_spec_generators,
          "priv/templates/cms_gen.integration_provider"
        )

      assert_file(Path.join(templates_dir, "google.ex"), [
        "Assent.Strategy.Google",
        "google_client_id",
        "google_client_secret",
        "access_type",
        "offline"
      ])
    end

    test "Facebook provider template exists with correct patterns" do
      templates_dir =
        Application.app_dir(
          :code_my_spec_generators,
          "priv/templates/cms_gen.integration_provider"
        )

      assert_file(Path.join(templates_dir, "facebook.ex"), [
        "Assent.Strategy.Facebook",
        "facebook_app_id",
        "facebook_app_secret"
      ])
    end

    test "QuickBooks provider template with token revocation" do
      templates_dir =
        Application.app_dir(
          :code_my_spec_generators,
          "priv/templates/cms_gen.integration_provider"
        )

      assert_file(Path.join(templates_dir, "quickbooks.ex"), [
        "Assent.Strategy.OAuth2",
        "quickbooks_client_id",
        "quickbooks_client_secret",
        "revoke_token",
        "appcenter.intuit.com",
        "com.intuit.quickbooks.accounting"
      ])
    end

    test "generic provider template uses OAuth2 strategy" do
      templates_dir =
        Application.app_dir(
          :code_my_spec_generators,
          "priv/templates/cms_gen.integration_provider"
        )

      assert_file(Path.join(templates_dir, "provider.ex"), [
        "Assent.Strategy.OAuth2",
        "<%= provider_module %>",
        "<%= provider_key %>",
        "normalize_user"
      ])
    end
  end
end
