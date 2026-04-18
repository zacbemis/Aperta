defmodule Aperta.Library do
  @moduledoc """
  Document library context.

  Owns the lifecycle of `Aperta.Documents.Document` rows — creating them from
  uploads, listing the current user's shelf, recording the user's current
  page, and deleting entries. All queries are scoped to `Scope.user`.
  """

  import Ecto.Query

  alias Aperta.Accounts.Scope
  alias Aperta.Documents.Document
  alias Aperta.Repo

  @doc "Lists a user's documents, most recently updated first."
  @spec list_documents(Scope.t()) :: [Document.t()]
  def list_documents(%Scope{user: user}) do
    Document
    |> where([d], d.user_id == ^user.id)
    |> order_by([d], desc: d.updated_at)
    |> Repo.all()
  end

  @doc """
  Fetches a document by id, raising if it doesn't belong to the scope's user.
  """
  @spec get_document!(Scope.t(), integer() | String.t()) :: Document.t()
  def get_document!(%Scope{user: user}, id) do
    Document
    |> where([d], d.user_id == ^user.id and d.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Inserts a new document for the scope's user.

  `attrs` must include every required field of `Document.create_changeset/2`.
  """
  @spec create_document(Scope.t(), map()) ::
          {:ok, Document.t()} | {:error, Ecto.Changeset.t()}
  def create_document(%Scope{user: user}, attrs) do
    %Document{user_id: user.id}
    |> Document.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Records the document's total page count once it's known.

  Called client-side by the PDF.js viewer after it finishes loading the file.
  Idempotent — safe to call more than once with the same value.
  """
  @spec set_page_count(Scope.t(), Document.t(), pos_integer()) ::
          {:ok, Document.t()} | {:error, Ecto.Changeset.t()}
  def set_page_count(%Scope{user: user}, %Document{user_id: uid} = document, count)
      when user.id == uid do
    document
    |> Document.page_count_changeset(%{page_count: count})
    |> Repo.update()
  end

  @doc """
  Moves a document's `current_page` to `page`, respecting last-writer-wins.

  The write is only applied when `client_updated_at` is strictly newer than
  the document's current `current_page_updated_at` (or when that column is
  `nil`). Older or equal timestamps are ignored. Either way, `{:ok, doc}` is
  returned with the latest persisted state — the UI doesn't need to
  distinguish between "you won the race" and "someone else's more recent
  update stuck".
  """
  @spec update_current_page(Scope.t(), Document.t(), %{
          page: pos_integer(),
          client_updated_at: DateTime.t()
        }) :: {:ok, Document.t()}
  def update_current_page(
        %Scope{user: user},
        %Document{user_id: uid} = document,
        %{page: page, client_updated_at: %DateTime{} = ts}
      )
      when user.id == uid and is_integer(page) and page >= 1 do
    {_count, _} =
      from(d in Document,
        where: d.id == ^document.id,
        where: d.user_id == ^user.id,
        where:
          is_nil(d.current_page_updated_at) or
            d.current_page_updated_at < ^ts,
        update: [
          set: [
            current_page: ^page,
            current_page_updated_at: ^ts
          ]
        ]
      )
      |> Repo.update_all([])

    {:ok, Repo.reload!(document)}
  end

  @doc "Deletes a document row. Storage cleanup is the caller's responsibility."
  @spec delete_document(Scope.t(), Document.t()) ::
          {:ok, Document.t()} | {:error, Ecto.Changeset.t()}
  def delete_document(%Scope{user: user}, %Document{user_id: uid} = document)
      when user.id == uid do
    Repo.delete(document)
  end
end
