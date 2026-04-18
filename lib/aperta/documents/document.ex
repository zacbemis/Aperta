defmodule Aperta.Documents.Document do
  @moduledoc """
  A document in a user's library — a PDF today, other formats later.

  `current_page` / `current_page_updated_at` hold the cross-device reading
  position. Updates are gated by a last-writer-wins rule in
  `Aperta.Library.update_current_page/3`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @supported_formats ~w(pdf)

  schema "documents" do
    field :format, :string, default: "pdf"
    field :title, :string
    field :author, :string
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :storage_key, :string
    field :page_count, :integer
    field :current_page, :integer, default: 1
    field :current_page_updated_at, :utc_datetime_usec

    belongs_to :user, Aperta.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Changeset used when a user uploads a new document."
  def create_changeset(document, attrs) do
    document
    |> cast(attrs, [
      :format,
      :title,
      :author,
      :filename,
      :content_type,
      :byte_size,
      :storage_key
    ])
    |> validate_required([
      :format,
      :title,
      :filename,
      :content_type,
      :byte_size,
      :storage_key
    ])
    |> validate_inclusion(:format, @supported_formats)
    |> validate_length(:title, max: 500)
    |> validate_length(:filename, max: 500)
    |> validate_length(:author, max: 500)
    |> validate_number(:byte_size, greater_than_or_equal_to: 0)
    |> unique_constraint(:storage_key)
  end

  @doc """
  Sets `page_count` once it's known (captured client-side by PDF.js on first
  open).
  """
  def page_count_changeset(document, attrs) do
    document
    |> cast(attrs, [:page_count])
    |> validate_required([:page_count])
    |> validate_number(:page_count, greater_than: 0)
  end
end
