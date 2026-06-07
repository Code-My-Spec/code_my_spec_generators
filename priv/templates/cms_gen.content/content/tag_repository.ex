defmodule <%= app_module %>.Content.TagRepository do
  @moduledoc """
  Query builder module for tag upsert and lookup.

  Handles tag normalization and conflict resolution on unique constraints.
  Tags are single-tenant (no account_id/project_id scoping) and shared globally
  across the deployed content system.
  """

  import Ecto.Query, warn: false

  alias <%= app_module %>.Repo
  alias <%= app_module %>.Content.Tag

  @spec upsert_tag(String.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def upsert_tag(name) do
    slug = slugify(name)

    case Repo.get_by(Tag, slug: slug) do
      nil ->
        %Tag{}
        |> Tag.changeset(%{name: name, slug: slug})
        |> Repo.insert()

      tag ->
        {:ok, tag}
    end
  end

  @spec list_tags() :: [Tag.t()]
  def list_tags do
    from(t in Tag)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @spec get_tag_by_slug(String.t()) :: Tag.t() | nil
  def get_tag_by_slug(slug) do
    from(t in Tag)
    |> by_slug(slug)
    |> Repo.one()
  end

  @spec get_tag_by_slug!(String.t()) :: Tag.t()
  def get_tag_by_slug!(slug) do
    from(t in Tag)
    |> by_slug(slug)
    |> Repo.one!()
  end

  @spec by_slug(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_slug(query, slug) do
    where(query, [t], t.slug == ^slug)
  end

  # Helper to generate slug from name
  defp slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
