defmodule <%= app_module %>.Content.Content do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          slug: String.t(),
          title: String.t() | nil,
          content_type: :blog | :page | :landing | :documentation,
          processed_content: String.t(),
          protected: boolean(),
          publish_at: DateTime.t() | nil,
          expires_at: DateTime.t() | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_image: String.t() | nil,
          og_title: String.t() | nil,
          og_description: String.t() | nil,
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "contents" do
    field :slug, :string
    field :title, :string
    field :content_type, Ecto.Enum, values: [:blog, :page, :landing, :documentation]
    field :processed_content, :string
    field :protected, :boolean, default: false
    field :publish_at, :utc_datetime
    field :expires_at, :utc_datetime

    field :meta_title, :string
    field :meta_description, :string
    field :og_image, :string
    field :og_title, :string
    field :og_description, :string
    field :metadata, :map, default: %{}

    many_to_many :tags, <%= app_module %>.Content.Tag,
      join_through: "content_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content, attrs) do
    content
    |> cast(attrs, [
      :slug,
      :title,
      :content_type,
      :processed_content,
      :protected,
      :publish_at,
      :expires_at,
      :meta_title,
      :meta_description,
      :og_image,
      :og_title,
      :og_description,
      :metadata
    ])
    |> validate_required([:slug, :content_type, :processed_content])
    |> validate_length(:meta_title, max: 60)
    |> validate_length(:meta_description, max: 160)
    |> validate_inclusion(:content_type, [:blog, :page, :landing, :documentation])
    |> validate_expiration_after_publish()
    |> unique_constraint([:slug, :content_type],
      name: :contents_slug_content_type_index
    )
  end

  defp validate_expiration_after_publish(changeset) do
    publish_at = get_field(changeset, :publish_at)
    expires_at = get_field(changeset, :expires_at)

    case {publish_at, expires_at} do
      {%DateTime{} = pub, %DateTime{} = exp} ->
        if DateTime.compare(exp, pub) == :gt do
          changeset
        else
          add_error(changeset, :expires_at, "must be after publish_at")
        end

      _ ->
        changeset
    end
  end
end
