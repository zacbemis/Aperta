defmodule Aperta.Repo do
  use Ecto.Repo,
    otp_app: :aperta,
    adapter: Ecto.Adapters.Postgres
end
