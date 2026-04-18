# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# `mix ecto.setup` and `mix ecto.reset` both invoke it automatically.
#
# Aperta supports open registration via `/users/register`, so seeding is
# optional — it exists purely as a dev convenience. If both
# `APERTA_USER_EMAIL` and `APERTA_USER_PASSWORD` are set in the environment,
# we provision a pre-confirmed account with those credentials; otherwise we
# leave the database untouched. Re-running the seed is idempotent.

alias Aperta.Accounts.User
alias Aperta.Repo

email = System.get_env("APERTA_USER_EMAIL")
password = System.get_env("APERTA_USER_PASSWORD")

cond do
  is_nil(email) or is_nil(password) ->
    IO.puts("""
    Seed: no APERTA_USER_EMAIL / APERTA_USER_PASSWORD set — skipping.
    Sign up through the UI at /users/register instead.
    """)

  Repo.get_by(User, email: email) ->
    IO.puts("Seed: user #{email} already exists, skipping.")

  true ->
    {:ok, user} =
      %User{}
      |> User.email_changeset(%{email: email})
      |> User.password_changeset(%{password: password})
      |> User.confirm_changeset()
      |> Repo.insert()

    IO.puts("""
    Seed: created user #{user.email}.
    Log in at /users/log-in with:
      email:    #{email}
      password: #{password}
    """)
end
