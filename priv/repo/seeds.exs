# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# `mix ecto.setup` and `mix ecto.reset` both invoke it automatically.
#
# Aperta v1 is intentionally single-user: there is no public registration
# route, so the one account is provisioned here. Re-running the seed is
# idempotent — if the user already exists we leave it alone.

alias Aperta.Accounts.User
alias Aperta.Repo

email = System.get_env("APERTA_USER_EMAIL", "admin@aperta.local")
password = System.get_env("APERTA_USER_PASSWORD", "aperta-dev-password")

case Repo.get_by(User, email: email) do
  %User{} ->
    IO.puts("Seed: user #{email} already exists, skipping.")

  nil ->
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
    Override via the APERTA_USER_EMAIL / APERTA_USER_PASSWORD env vars.
    """)
end
