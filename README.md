# Aperta

A multi-user PDF reader with cross-device page sync, built on Phoenix v1.8.
Upload your PDFs, open them in any browser, and the current page follows you
around — LiveView + `Phoenix.PubSub` keep every tab for the same document in
lockstep.

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.15+ / Erlang/OTP 26+
- [Docker](https://docs.docker.com/get-docker/) with Compose v2 (for local Postgres and MinIO)

## Quickstart

```bash
docker compose up -d       # start Postgres (5432) + MinIO (9000 API, 9001 console)
mix setup                  # fetch deps, create/migrate DB, build assets, vendor PDF.js
mix phx.server             # or: iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000). The MinIO console is at
[`localhost:9001`](http://localhost:9001) (default dev credentials:
`aperta` / `aperta-dev-password`). The `aperta-documents` bucket is created
automatically by the `minio-setup` one-shot service.

`mix setup` also runs `mix aperta.vendor.pdfjs`, which downloads Mozilla's
prebuilt PDF.js viewer into `priv/static/vendor/pdfjs/` — that's the reader
UI the iframe loads. The zip is cached under `_build/` so subsequent runs
are a no-op.

Stop everything with `docker compose down`. Wipe the data volumes with
`docker compose down -v`.

### Overriding the MinIO dev credentials

```bash
APERTA_MINIO_ROOT_USER=alice \
APERTA_MINIO_ROOT_PASSWORD=hunter2 \
APERTA_MINIO_BUCKET=my-docs \
  docker compose up -d
```

## Getting an account

Registration is open — head to
[`localhost:4000/users/register`](http://localhost:4000/users/register) and
sign up with an email. The `phx.gen.auth` scaffold sends a magic-link
confirmation; you can add a password later on the settings page.

For local iteration you can also pre-seed a confirmed account via env vars:

```bash
APERTA_USER_EMAIL=me@example.com \
APERTA_USER_PASSWORD=correct-horse-battery-staple \
  mix run priv/repo/seeds.exs
```

(Both vars are optional; if either is missing the seed script is a no-op.
`mix ecto.setup` and `mix ecto.reset` run the seed for you.)

## Trying the app end-to-end

1. Sign in and go to [`localhost:4000/library`](http://localhost:4000/library).
2. Drag a PDF onto the dropzone (or click it to browse). Up to 10 files at a
   time, 500 MB each. Uploads go straight to MinIO; a row appears in the
   library stream as soon as the object is in place.
3. Click a row to open the reader. PDF.js loads the file through a
   same-origin Phoenix endpoint (`GET /library/:id/file`) that streams
   byte-ranges from MinIO, so page turns lazy-load the chunks they need.
4. Press `Esc` (with focus outside the PDF.js iframe) to pop back to the
   library. Use the trash icon on any card to delete the row — the MinIO
   object is deleted alongside it.

### Trying cross-device sync

The whole point of v1. With one account:

1. Open the same document in two different browsers (or one normal window and
   one private/incognito — just not two tabs in the same browser, which share
   the LiveView socket state).
2. Sign in as the same user on both.
3. Scroll a few pages in window A. Window B should jump to match within a
   few hundred milliseconds. Flip it the other way to confirm both sides
   broadcast.
4. Close and reopen either window — it resumes on the last synced page
   (`documents.current_page` in Postgres).

Origin IDs on the broadcasts keep each device from echoing its own page
changes back to itself, and a `current_page_updated_at` column enforces
last-writer-wins if two devices move at the same time.

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
