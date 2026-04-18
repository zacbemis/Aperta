# Aperta

A Phoenix v1.8 (Elixir) web application.

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.15+ / Erlang/OTP 26+
- [Docker](https://docs.docker.com/get-docker/) with Compose v2 (for local Postgres and MinIO)

## Quickstart

```bash
docker compose up -d       # start Postgres (5432) + MinIO (9000 API, 9001 console)
mix setup                  # fetch deps, create/migrate DB, build assets
mix phx.server             # or: iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000). The MinIO console is at
[`localhost:9001`](http://localhost:9001) (default dev credentials:
`aperta` / `aperta-dev-password`). The `aperta-documents` bucket is created
automatically by the `minio-setup` one-shot service.

Stop everything with `docker compose down`. Wipe the data volumes with
`docker compose down -v`.

### Overriding the MinIO dev credentials

```bash
APERTA_MINIO_ROOT_USER=alice \
APERTA_MINIO_ROOT_PASSWORD=hunter2 \
APERTA_MINIO_BUCKET=my-docs \
  docker compose up -d
```

## Useful commands

- `mix test` — run the test suite (ExUnit).
- `mix precommit` — the pre-commit gate: `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, `test`. Run this before committing.
- `mix ecto.reset` — drop, recreate, migrate, and seed the dev database.
- `mix ecto.gen.migration <name_with_underscores>` — create a new migration.
- `mix phx.routes` — list all routes.

## Project conventions

Agent and contributor rules live in [`.cursor/rules/`](.cursor/rules/):

- [`code.md`](.cursor/rules/code.md) — Elixir / Phoenix / HEEx / LiveView / Ecto / Tailwind standards.
- [`architecture.md`](.cursor/rules/architecture.md) — folder layout and module conventions.
- [`tests.md`](.cursor/rules/tests.md) — test patterns and debugging.
- [`plans.md`](.cursor/rules/plans.md) — how to execute multi-step plans.

## Learn more

- Phoenix: https://www.phoenixframework.org/ · [guides](https://hexdocs.pm/phoenix/overview.html) · [docs](https://hexdocs.pm/phoenix)
- Elixir Forum: https://elixirforum.com/c/phoenix-forum
