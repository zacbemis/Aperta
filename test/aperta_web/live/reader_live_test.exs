defmodule ApertaWeb.ReaderLiveTest do
  use ApertaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aperta.LibraryFixtures

  alias Aperta.Library
  alias Aperta.Repo

  describe "access control" do
    test "unauthenticated visitors are redirected to the login page", %{conn: conn} do
      scope = Aperta.AccountsFixtures.user_scope_fixture()
      doc = document_fixture(scope)

      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/library/#{doc.id}")
      assert to == ~p"/users/log-in"
    end

    test "cannot open another user's document", %{conn: conn} do
      other_scope = Aperta.AccountsFixtures.user_scope_fixture()
      theirs = document_fixture(other_scope)

      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/library/#{theirs.id}")
      end
    end
  end

  describe "authenticated reader" do
    setup :register_and_log_in_user

    test "renders the document title and an iframe pointed at the vendored viewer",
         %{conn: conn, scope: scope} do
      doc = document_fixture(scope, title: "War and Peace")

      {:ok, lv, html} = live(conn, ~p"/library/#{doc.id}")

      assert html =~ "War and Peace"
      assert has_element?(lv, "iframe#pdf-viewer")
      # iframe `src` points at the vendored viewer, and the `?file=`
      # parameter is a same-origin Phoenix URL (so PDF.js's origin check
      # doesn't reject it).
      assert has_element?(
               lv,
               ~s|iframe#pdf-viewer[src^="/vendor/pdfjs/web/viewer.html?file="]|
             )

      encoded = URI.encode_www_form("/library/#{doc.id}/file")
      assert html =~ encoded
    end

    test "pages_loaded persists page_count and jumps the viewer when resuming mid-document",
         %{conn: conn, scope: scope} do
      {:ok, doc} =
        Library.update_current_page(scope, document_fixture(scope), %{
          page: 7,
          client_updated_at: DateTime.utc_now()
        })

      {:ok, lv, _html} = live(conn, ~p"/library/#{doc.id}")

      render_hook(lv, "pages_loaded", %{"num_pages" => 42})

      reloaded = Repo.reload!(doc)
      assert reloaded.page_count == 42
      assert_push_event(lv, "sync_to", %{page: 7})
    end

    test "pages_loaded does not push sync_to when still on page 1",
         %{conn: conn, scope: scope} do
      doc = document_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/library/#{doc.id}")

      render_hook(lv, "pages_loaded", %{"num_pages" => 10})

      assert Repo.reload!(doc).page_count == 10
      refute_push_event(lv, "sync_to", 100)
    end

    test "page_changed stores the new page and broadcasts to other subscribers",
         %{conn: conn, scope: scope} do
      doc = document_fixture(scope)
      topic = "document:#{doc.id}"
      :ok = Phoenix.PubSub.subscribe(Aperta.PubSub, topic)

      {:ok, lv, _html} = live(conn, ~p"/library/#{doc.id}")

      now = DateTime.utc_now()

      render_hook(lv, "page_changed", %{
        "page" => 5,
        "client_updated_at" => DateTime.to_iso8601(now)
      })

      assert_receive {:page_updated, 5, origin}
      assert is_binary(origin)
      assert Repo.reload!(doc).current_page == 5
    end

    test "page_changed with an older timestamp does not move the stored page and resyncs the viewer",
         %{conn: conn, scope: scope} do
      doc = document_fixture(scope)
      later = DateTime.utc_now()
      earlier = DateTime.add(later, -60, :second)

      {:ok, _} =
        Library.update_current_page(scope, doc, %{page: 9, client_updated_at: later})

      {:ok, lv, _html} = live(conn, ~p"/library/#{doc.id}")

      render_hook(lv, "page_changed", %{
        "page" => 3,
        "client_updated_at" => DateTime.to_iso8601(earlier)
      })

      assert Repo.reload!(doc).current_page == 9
      assert_push_event(lv, "sync_to", %{page: 9})
    end

    test "page_updated messages from other origins push sync_to", %{conn: conn, scope: scope} do
      doc = document_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/library/#{doc.id}")

      send(lv.pid, {:page_updated, 12, "some-other-origin"})

      assert_push_event(lv, "sync_to", %{page: 12})
    end

    test "page_updated messages from the same origin are ignored", %{conn: conn, scope: scope} do
      doc = document_fixture(scope)

      {:ok, lv, html} = live(conn, ~p"/library/#{doc.id}")

      [own_origin] =
        Regex.run(~r/data-origin-id="([^"]+)"/, html, capture: :all_but_first)

      send(lv.pid, {:page_updated, 77, own_origin})

      refute_push_event(lv, "sync_to", 100)
    end
  end
end
