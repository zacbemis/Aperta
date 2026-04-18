defmodule ApertaWeb.UserLive.RegistrationTest do
  use ApertaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aperta.AccountsFixtures

  alias Aperta.Accounts

  describe "rendering" do
    test "renders the registration form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create your account"
      assert html =~ "Email"
    end

    test "already-authenticated users are redirected to the library", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/users/register")
      assert to == ~p"/library"
    end
  end

  describe "submitting the form" do
    test "creates the user and delivers a confirmation email", %{conn: conn} do
      email = unique_user_email()
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _lv, html} =
        form(lv, "#registration_form", user: %{email: email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "you&#39;ll receive a confirmation link"

      assert user = Accounts.get_user_by_email(email)
      assert user.confirmed_at == nil

      assert Aperta.Repo.get_by!(Aperta.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose that the email is already registered", %{conn: conn} do
      existing = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _lv, html} =
        form(lv, "#registration_form", user: %{email: existing.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "you&#39;ll receive a confirmation link"

      # A magic-link login token was issued for the existing user rather than
      # a second User row being created.
      assert [user] = Aperta.Repo.all(Aperta.Accounts.User)
      assert user.id == existing.id

      assert Aperta.Repo.get_by!(Aperta.Accounts.UserToken, user_id: existing.id).context ==
               "login"
    end

    test "surfaces validation errors for an invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        form(lv, "#registration_form", user: %{email: "not-an-email"})
        |> render_submit()

      assert html =~ "must have the @ sign and no spaces"
      assert Aperta.Repo.aggregate(Aperta.Accounts.User, :count) == 0
    end
  end
end
