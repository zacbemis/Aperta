defmodule Aperta.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :format, :string, null: false, default: "pdf"
      add :title, :string, null: false
      add :author, :string
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :storage_key, :string, null: false
      add :page_count, :integer
      add :current_page, :integer, null: false, default: 1
      add :current_page_updated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:documents, [:user_id])
    create unique_index(:documents, [:storage_key])

    create constraint(:documents, :current_page_must_be_positive, check: "current_page >= 1")

    create constraint(:documents, :byte_size_must_be_positive, check: "byte_size >= 0")
  end
end
