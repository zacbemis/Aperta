---
applyIntelligently: true
---

# Architecture

Phoenix v1.8 web application (Elixir).

## Folder layout

- `lib/aperta/` — domain/business logic, `Aperta.Repo`, `Aperta.Mailer`, supervisors.
- `lib/aperta_web/` — web layer: `Endpoint`, `Router`, controllers, components, layouts, telemetry.
  - `lib/aperta_web.ex` is the shared `use ApertaWeb, :...` module. App-wide imports/aliases belong in its `html_helpers` block so they're available to every LiveView, LiveComponent, and `use ApertaWeb, :html`.
- `assets/` — esbuild + Tailwind v4 + daisyUI sources. Only `app.js` and `app.css` are bundled.
- `config/` — `config.exs`, `dev.exs`, `test.exs`, `prod.exs`, `runtime.exs`.
- `priv/repo/migrations/` — Ecto migrations. Generate with `mix ecto.gen.migration name_with_underscores` so timestamps/conventions are correct.
- `priv/gettext/` — translations. `priv/static/` — static assets.
- `test/` — ExUnit tests. `test/support/{conn_case,data_case}.ex` are the shared test case modules.

## Module conventions

- **One module per file.** Nesting modules in a single file can cause cyclic deps and compile errors.
- `ApertaWeb.Layouts` is already aliased in `lib/aperta_web.ex` — use it directly, don't re-alias.
- **Router `scope` blocks provide the module alias** — never add your own alias on top:

  ```elixir
  scope "/admin", ApertaWeb.Admin do
    pipe_through :browser
    live "/users", UserLive, :index   # → ApertaWeb.Admin.UserLive
  end
  ```

- **LiveView modules** use a `Live` suffix, e.g. `ApertaWeb.WeatherLive`. The default `:browser` scope is already aliased to `ApertaWeb`, so routes are terse: `live "/weather", WeatherLive`.
- `Phoenix.View` is no longer part of Phoenix — don't reintroduce it.
