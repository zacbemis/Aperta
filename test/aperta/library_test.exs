defmodule Aperta.LibraryTest do
  use Aperta.DataCase, async: true

  import Aperta.AccountsFixtures
  import Aperta.LibraryFixtures

  alias Aperta.Library
  alias Aperta.Documents.Document

  describe "create_document/2" do
    setup do: %{scope: user_scope_fixture()}

    test "inserts a document scoped to the caller", %{scope: scope} do
      attrs = valid_document_attrs(title: "Moby-Dick")
      assert {:ok, %Document{} = doc} = Library.create_document(scope, attrs)

      assert doc.title == "Moby-Dick"
      assert doc.user_id == scope.user.id
      assert doc.current_page == 1
      assert is_nil(doc.current_page_updated_at)
    end

    test "rejects missing required fields", %{scope: scope} do
      assert {:error, changeset} = Library.create_document(scope, %{})
      errors = errors_on(changeset)

      for field <- [:title, :filename, :content_type, :byte_size, :storage_key] do
        assert errors[field], "expected error on #{field}, got: #{inspect(errors)}"
      end
    end

    test "rejects unsupported formats", %{scope: scope} do
      attrs = valid_document_attrs(format: "epub")
      assert {:error, changeset} = Library.create_document(scope, attrs)
      assert %{format: ["is invalid"]} = errors_on(changeset)
    end

    test "enforces a unique storage_key", %{scope: scope} do
      attrs = valid_document_attrs()
      assert {:ok, _} = Library.create_document(scope, attrs)
      assert {:error, changeset} = Library.create_document(scope, attrs)
      assert %{storage_key: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "list_documents/1" do
    setup do: %{scope: user_scope_fixture()}

    test "returns only the scope's documents, newest first", %{scope: scope} do
      other_scope = user_scope_fixture()

      _theirs = document_fixture(other_scope, title: "Not mine")
      a = document_fixture(scope, title: "First")
      b = document_fixture(scope, title: "Second")

      ids = Library.list_documents(scope) |> Enum.map(& &1.id)
      assert ids == [b.id, a.id]
    end
  end

  describe "get_document!/2" do
    setup do: %{scope: user_scope_fixture()}

    test "returns a document owned by the scope", %{scope: scope} do
      doc = document_fixture(scope)
      assert %Document{id: id} = Library.get_document!(scope, doc.id)
      assert id == doc.id
    end

    test "raises for a document owned by a different user", %{scope: scope} do
      other_scope = user_scope_fixture()
      doc = document_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Library.get_document!(scope, doc.id)
      end
    end
  end

  describe "update_current_page/3 — last-writer-wins" do
    setup do
      scope = user_scope_fixture()
      doc = document_fixture(scope)
      %{scope: scope, doc: doc}
    end

    test "accepts an initial write when current_page_updated_at is nil",
         %{scope: scope, doc: doc} do
      ts = DateTime.utc_now()

      assert {:ok, updated} =
               Library.update_current_page(scope, doc, %{page: 42, client_updated_at: ts})

      assert updated.current_page == 42
      assert DateTime.compare(updated.current_page_updated_at, ts) == :eq
    end

    test "newer timestamp wins", %{scope: scope, doc: doc} do
      t0 = DateTime.utc_now()
      t1 = DateTime.add(t0, 5, :second)

      {:ok, doc} = Library.update_current_page(scope, doc, %{page: 10, client_updated_at: t0})
      {:ok, doc} = Library.update_current_page(scope, doc, %{page: 20, client_updated_at: t1})

      assert doc.current_page == 20
      assert DateTime.compare(doc.current_page_updated_at, t1) == :eq
    end

    test "older timestamp is ignored but still returns the latest state",
         %{scope: scope, doc: doc} do
      t_new = DateTime.utc_now()
      t_old = DateTime.add(t_new, -10, :second)

      {:ok, doc} =
        Library.update_current_page(scope, doc, %{page: 50, client_updated_at: t_new})

      {:ok, same} =
        Library.update_current_page(scope, doc, %{page: 3, client_updated_at: t_old})

      assert same.current_page == 50
      assert DateTime.compare(same.current_page_updated_at, t_new) == :eq
    end

    test "equal timestamp is a no-op (ties go to the existing write)",
         %{scope: scope, doc: doc} do
      ts = DateTime.utc_now()

      {:ok, doc} = Library.update_current_page(scope, doc, %{page: 7, client_updated_at: ts})
      {:ok, doc} = Library.update_current_page(scope, doc, %{page: 999, client_updated_at: ts})

      assert doc.current_page == 7
    end
  end

  describe "set_page_count/3" do
    setup do
      scope = user_scope_fixture()
      doc = document_fixture(scope)
      %{scope: scope, doc: doc}
    end

    test "stores the page count", %{scope: scope, doc: doc} do
      assert {:ok, updated} = Library.set_page_count(scope, doc, 321)
      assert updated.page_count == 321
    end

    test "rejects non-positive page counts", %{scope: scope, doc: doc} do
      assert {:error, changeset} = Library.set_page_count(scope, doc, 0)
      assert %{page_count: [_]} = errors_on(changeset)
    end
  end

  describe "delete_document/2" do
    test "deletes a document owned by the scope" do
      scope = user_scope_fixture()
      doc = document_fixture(scope)

      assert {:ok, _} = Library.delete_document(scope, doc)

      assert_raise Ecto.NoResultsError, fn ->
        Library.get_document!(scope, doc.id)
      end
    end
  end
end
