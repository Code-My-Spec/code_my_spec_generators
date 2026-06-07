defmodule <%= app_module %>.Content.Tag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          slug: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "tags" do
    field :name, :string
    field :slug, :string

    many_to_many :content, <%= app_module %>.Content.Content,
      join_through: "content_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 50)
    |> unique_constraint(:slug, name: :tags_slug_index)
  end
end
