defmodule ApertaWeb.HomeLiveTest do
  use ApertaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "anonymous visitor" do
    test "renders the marketing copy and primary CTAs", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/")

      assert html =~ "Your PDF library"
      assert has_element?(lv, "a[href='#{~p"/users/register"}']", "Create an account")
      assert has_element?(lv, "a[href='#{~p"/users/log-in"}']", "I already have an account")
    end
  end

  describe "authenticated visitor" do
    setup :register_and_log_in_user

    test "swaps the CTAs for a 'go to library' button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert has_element?(lv, "a[href='#{~p"/library"}']", "Go to your library")
      refute has_element?(lv, "a[href='#{~p"/users/register"}']")
    end
  end
end
