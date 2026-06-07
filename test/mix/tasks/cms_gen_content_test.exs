defmodule Mix.Tasks.CmsGen.ContentTest do
  use ExUnit.Case, async: false

  import CodeMySpecGenerators.GeneratorTestHelpers

  @moduletag :generator

  describe "cms_gen.content" do
    test "generates all expected content files" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.content")

      assert_file(Path.join(templates_dir, "content.ex"))
      assert_file(Path.join(templates_dir, "content/content.ex"))
      assert_file(Path.join(templates_dir, "content/tag.ex"))
      assert_file(Path.join(templates_dir, "content/content_tag.ex"))
      assert_file(Path.join(templates_dir, "content/content_repository.ex"))
      assert_file(Path.join(templates_dir, "content/tag_repository.ex"))
      assert_file(Path.join(templates_dir, "migration.exs"))
    end

    test "content schema template contains EEx bindings and fields" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.content")

      assert_file(Path.join(templates_dir, "content/content.ex"), [
        "<%= app_module %>.Content.Content",
        "schema \"contents\"",
        ":content_type",
        ":processed_content",
        ":protected",
        "many_to_many :tags, <%= app_module %>.Content.Tag",
        "contents_slug_content_type_index"
      ])
    end

    test "content repository is scope-aware and single-tenant" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.content")

      assert_file(Path.join(templates_dir, "content/content_repository.ex"), [
        "alias <%= app_module %>.Users.Scope",
        "def list_published_content(%Scope{}",
        "def list_published_content(nil,",
        "c.protected == false",
        "def get_content_by_slug"
      ])
    end

    test "content context exposes publishing/sync flow" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.content")

      assert_file(Path.join(templates_dir, "content.ex"), [
        "<%= app_module %>.Content",
        "def sync_content",
        "def sync_content_tags",
        "def upsert_tag",
        "def list_published_content"
      ])
    end

    test "content context inlines changeset error formatting (no Utils dependency)" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.content")

      content = File.read!(Path.join(templates_dir, "content.ex"))
      refute String.contains?(content, "Utils.changeset_error_to_string")
      assert String.contains?(content, "defp changeset_error_to_string")
    end

    test "migration creates contents, tags, and content_tags tables" do
      templates_dir =
        Application.app_dir(:code_my_spec_generators, "priv/templates/cms_gen.content")

      assert_file(Path.join(templates_dir, "migration.exs"), [
        "create table(:contents",
        "create table(:tags",
        "create table(:content_tags",
        "contents_slug_content_type_index",
        "tags_slug_index",
        "references(:contents, on_delete: :delete_all)",
        "references(:tags, on_delete: :delete_all)"
      ])
    end
  end
end
