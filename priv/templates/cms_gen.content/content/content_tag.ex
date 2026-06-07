defmodule <%= app_module %>.Content.ContentTag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          content_id: integer(),
          tag_id: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "content_tags" do
    belongs_to :content, <%= app_module %>.Content.Content
    belongs_to :tag, <%= app_module %>.Content.Tag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_tag, attrs) do
    content_tag
    |> cast(attrs, [:content_id, :tag_id])
    |> validate_required([:content_id, :tag_id])
    |> foreign_key_constraint(:content_id)
    |> foreign_key_constraint(:tag_id)
    |> unique_constraint([:content_id, :tag_id],
      name: :content_tags_content_id_tag_id_index
    )
  end
end
