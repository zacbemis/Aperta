defmodule ApertaWeb.DocumentControllerTest do
  use ApertaWeb.ConnCase, async: true

  import Aperta.LibraryFixtures

  alias Aperta.Storage

  describe "GET /library/:id/file" do
    test "unauthenticated visitors are redirected to log in", %{conn: conn} do
      scope = Aperta.AccountsFixtures.user_scope_fixture()
      doc = document_fixture(scope)

      conn = get(conn, ~p"/library/#{doc.id}/file")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "returns 404 for a document owned by another user", %{conn: conn} do
      other_scope = Aperta.AccountsFixtures.user_scope_fixture()
      theirs = document_fixture(other_scope)

      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/library/#{theirs.id}/file")
      end
    end

    @tag :storage
    test "streams the full document bytes with the right headers", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})

      contents = "%PDF-1.4\nhello world\n%%EOF\n"
      doc = put_and_fixture(scope, contents)

      conn = get(conn, ~p"/library/#{doc.id}/file")

      assert response(conn, 200) == contents
      assert get_resp_header(conn, "content-type") == ["application/pdf"]
      assert get_resp_header(conn, "content-disposition") == [~s|inline; filename="paper.pdf"|]
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    end

    @tag :storage
    test "streams a Range request as 206 Partial Content", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})

      contents = "%PDF-1.4\nhello world\n%%EOF\n"
      total = byte_size(contents)
      doc = put_and_fixture(scope, contents)

      conn =
        conn
        |> put_req_header("range", "bytes=0-4")
        |> get(~p"/library/#{doc.id}/file")

      assert response(conn, 206) == binary_part(contents, 0, 5)
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert get_resp_header(conn, "content-range") == ["bytes 0-4/#{total}"]
    end

    @tag :storage
    test "supports open-ended ranges (bytes=N-)", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})

      contents = "%PDF-1.4\nhello world\n%%EOF\n"
      total = byte_size(contents)
      doc = put_and_fixture(scope, contents)

      conn =
        conn
        |> put_req_header("range", "bytes=8-")
        |> get(~p"/library/#{doc.id}/file")

      tail = binary_part(contents, 8, total - 8)
      assert response(conn, 206) == tail
      assert get_resp_header(conn, "content-range") == ["bytes 8-#{total - 1}/#{total}"]
    end

    test "returns 416 for an unsatisfiable range", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})

      # Use a sentinel byte_size without actually uploading — the range is
      # rejected before we ever hit storage.
      doc = document_fixture(scope, byte_size: 100)

      conn =
        conn
        |> put_req_header("range", "bytes=999-1000")
        |> get(~p"/library/#{doc.id}/file")

      assert response(conn, 416)
      assert get_resp_header(conn, "content-range") == ["bytes */100"]
    end
  end

  defp put_and_fixture(scope, contents) do
    key = "documents/#{scope.user.id}/#{Ecto.UUID.generate()}.pdf"
    :ok = Storage.put(key, contents, content_type: "application/pdf")
    on_exit(fn -> Storage.delete(key) end)

    document_fixture(scope,
      filename: "paper.pdf",
      content_type: "application/pdf",
      byte_size: byte_size(contents),
      storage_key: key
    )
  end
end
