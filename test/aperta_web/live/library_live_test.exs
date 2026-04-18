defmodule ApertaWeb.LibraryLiveTest do
  use ApertaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aperta.LibraryFixtures

  alias Aperta.Storage

  @sample_pdf_path Path.expand("../../support/fixtures/files/sample.pdf", __DIR__)

  describe "access control" do
    test "unauthenticated visitors to /library are redirected to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/library")
      assert to == ~p"/users/log-in"
    end
  end

  describe "authenticated library index" do
    setup :register_and_log_in_user

    test "renders the heading and empty-state copy", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/library")

      assert html =~ "Your library"
      assert has_element?(lv, "#documents-empty", "No documents yet")
    end

    test "shows documents owned by the current user", %{conn: conn, scope: scope} do
      doc = document_fixture(scope, title: "The Great Book")

      {:ok, lv, _html} = live(conn, ~p"/library")

      assert has_element?(lv, "#documents #documents-#{doc.id}", "The Great Book")
    end

    test "does not leak other users' documents", %{conn: conn} do
      other_scope = Aperta.AccountsFixtures.user_scope_fixture()
      _theirs = document_fixture(other_scope, title: "Not for this user")

      {:ok, lv, _html} = live(conn, ~p"/library")

      refute has_element?(lv, "#documents", "Not for this user")
      assert has_element?(lv, "#documents-empty")
    end

    test "renders the upload dropzone form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/library")

      assert has_element?(lv, "#upload-form")
      assert has_element?(lv, "form#upload-form label[phx-drop-target]")
    end
  end

  describe "uploading a PDF" do
    @moduletag :storage

    setup :register_and_log_in_user

    test "writes the file to storage and creates a document row",
         %{conn: conn, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/library")

      contents = File.read!(@sample_pdf_path)

      input =
        file_input(lv, "#upload-form", :pdf, [
          %{name: "Moby-Dick.pdf", type: "application/pdf", content: contents}
        ])

      assert render_upload(input, "Moby-Dick.pdf") =~ "Moby-Dick.pdf"

      render_submit(element(lv, "#upload-form"))

      assert has_element?(lv, "#documents article", "Moby-Dick")

      # The row exists in the DB
      [doc] = Aperta.Library.list_documents(scope)
      assert doc.title == "Moby-Dick"
      assert doc.filename == "Moby-Dick.pdf"
      assert doc.content_type == "application/pdf"
      assert doc.byte_size == byte_size(contents)
      assert String.starts_with?(doc.storage_key, "documents/#{scope.user.id}/")

      # And the object exists in MinIO
      on_exit(fn -> Storage.delete(doc.storage_key) end)
      assert {:ok, blob} = Storage.get(doc.storage_key)
      assert blob == contents
    end
  end
end
