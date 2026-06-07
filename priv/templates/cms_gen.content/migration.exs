defmodule <%= app_module %>.Repo.Migrations.CreateContentTables do
  use Ecto.Migration

  def change do
    create table(:contents) do
      add :slug, :string, null: false
      add :title, :string
      add :content_type, :string, null: false
      add :processed_content, :text
      add :protected, :boolean, default: false, null: false
      add :publish_at, :utc_datetime
      add :expires_at, :utc_datetime

      add :meta_title, :string
      add :meta_description, :string
      add :og_image, :string
      add :og_title, :string
      add :og_description, :string
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:contents, [:content_type])
    create index(:contents, [:protected])
    create index(:contents, [:publish_at, :expires_at])

    create unique_index(:contents, [:slug, :content_type],
             name: :contents_slug_content_type_index
           )

    create table(:tags) do
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:slug], name: :tags_slug_index)

    create table(:content_tags) do
      add :content_id, references(:contents, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:content_tags, [:content_id])
    create index(:content_tags, [:tag_id])
    create unique_index(:content_tags, [:content_id, :tag_id])
  end
end
