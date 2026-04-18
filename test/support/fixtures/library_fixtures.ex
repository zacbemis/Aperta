defmodule Aperta.LibraryFixtures do
  @moduledoc """
  Helpers for building `Aperta.Documents.Document` rows in tests.
  """

  alias Aperta.Library

  def valid_document_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      format: "pdf",
      title: "Fixture Doc #{unique}",
      author: "Jane Tester",
      filename: "fixture-#{unique}.pdf",
      content_type: "application/pdf",
      byte_size: 1234,
      storage_key: "documents/#{unique}.pdf"
    })
  end

  def document_fixture(scope, attrs \\ %{}) do
    {:ok, document} = Library.create_document(scope, valid_document_attrs(attrs))
    document
  end
end
