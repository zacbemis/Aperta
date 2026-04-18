---
alwaysApply: true
---

# Code standards

## Project-wide

- Run `mix precommit` before finishing any change; fix anything it reports.
- Use the already-included `Req` library for HTTP. **Avoid** `:httpoison`, `:tesla`, and `:httpc`.

## Elixir

- **Lists don't support index access** — `mylist[i]` is invalid. Use `Enum.at/2`, pattern matching, or `List`.
- Variables are immutable (but rebindable). Inside `if`/`case`/`cond`, **bind the result of the expression**; don't rebind inside it:

  ```elixir
  # INVALID — rebinds inside `if`, result is discarded
  if connected?(socket) do
    socket = assign(socket, :val, val)
  end

  # VALID
  socket =
    if connected?(socket) do
      assign(socket, :val, val)
    end
  ```

- **Don't use `struct[:field]`** — structs don't implement `Access`. Use `struct.field`, or a higher-level API like `Ecto.Changeset.get_field/2`.
- Prefer `Time`, `Date`, `DateTime`, `Calendar` from the standard library. Only add `date_time_parser` if you need parsing.
- **Never `String.to_atom/1` on user input** — memory leak risk.
- Predicate names end with `?` (e.g. `valid?`). Reserve `is_*` for guards only.
- OTP primitives (`DynamicSupervisor`, `Registry`, …) take a `name:` in their child spec:

  ```elixir
  {DynamicSupervisor, name: Aperta.MyDynamicSup}
  DynamicSupervisor.start_child(Aperta.MyDynamicSup, child_spec)
  ```

- Use `Task.async_stream/3` for concurrent enumeration with backpressure. Usually pass `timeout: :infinity`.

## Mix

- Read docs before using an unfamiliar task: `mix help <task>`.
- **Avoid `mix deps.clean --all`** — almost never needed.

## Ecto

- **Preload** associations in queries when templates will touch them (e.g. `message.user.email`).
- In `seeds.exs`, remember to `import Ecto.Query` and other supporting modules.
- Schema field type is `:string` even for `:text` columns: `field :name, :string`.
- `Ecto.Changeset.validate_number/2` does **not** support `:allow_nil`. Validations already skip missing/nil changes.
- Access changeset fields with `Ecto.Changeset.get_field(changeset, :field)` — not `changeset[:field]`.
- **Never** list programmatic fields (e.g. `user_id`) in `cast/3`; set them when building the struct.

## Phoenix v1.8 components

- **Always** begin LiveView templates with `<Layouts.app flash={@flash} ...>` wrapping the inner content.
- If you hit a missing `current_scope` assign: either your routes aren't in the right `live_session`, or you didn't pass `current_scope` to `<Layouts.app>`. Fix both.
- `<.flash_group>` now lives on `Layouts` — **never** call it outside `layouts.ex`.
- **Always** use the imported `<.icon name="hero-x-mark" class="w-5 h-5" />` for icons. Never a `Heroicons` module.
- **Always** use the imported `<.input>` from `core_components.ex` for form inputs. If you set `class=`, note that default classes are dropped and you must fully style it yourself.

## HEEx / HTML

- Templates are **always** `~H` or `.html.heex`. **Never** `~E`.
- Interpolation: `{...}` for values (in attributes or tag bodies). `<%= ... %>` only works in tag bodies, and only for block constructs (`if`, `cond`, `case`, `for`).

  ```heex
  <div id={@id}>
    {@my_assign}
    <%= if @show? do %>
      {@other}
    <% end %>
  </div>
  ```

- Elixir has **no `else if`/`elseif`** — use `cond` or `case` for multi-branch conditionals.
- HEEx class attrs support lists. **Always** use list syntax for multi-class values and wrap `if` inside `{...}` in parens:

  ```heex
  <a class={[
    "px-2 text-white",
    @flag && "py-5",
    if(@other, do: "border-red-500", else: "border-blue-100")
  ]}>Text</a>
  ```

- HEEx comments: `<%!-- comment --%>`.
- For collections, **always** `<%= for item <- @collection do %>`. Never `<% Enum.each %>` or other non-for comprehensions.
- To render literal `{` / `}` (e.g. code snippets), annotate the parent with `phx-no-curly-interpolation`:

  ```heex
  <code phx-no-curly-interpolation>
    let obj = {key: "val"}
  </code>
  ```

## Forms

- **Always** build forms via `Phoenix.Component.form/1` + `inputs_for/1`. Never the deprecated `Phoenix.HTML.form_for` / `inputs_for`.
- **Always** assign the form via `to_form/2` in the LiveView, and drive templates from `@form[:field]`:

  ```elixir
  assign(socket, form: to_form(changeset))
  ```

  ```heex
  <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
    <.input field={@form[:field]} type="text" />
  </.form>
  ```

- **Never** `for={@changeset}` or access `@changeset[:field]` in templates — it errors.
- **Never** use `<.form let={f} ...>`. Always `<.form for={@form} ...>`.
- Always give forms an explicit unique DOM `id`.
- Forms from params: `to_form(params)` (string keys). Nest with `to_form(user_params, as: :user)`.

## JS & CSS

- Tailwind v4 — **no `tailwind.config.js`**. Preserve the `app.css` import syntax:

  ```css
  @import "tailwindcss" source(none);
  @source "../css";
  @source "../js";
  @source "../../lib/aperta_web";
  ```

- **Never** use `@apply` in raw CSS.
- Write your own Tailwind components for a unique look — don't lean on daisyUI for UI.
- Only `app.js` / `app.css` bundles are supported. Import vendor deps into those files; **never** reference external `src`/`href` in layouts, and **never** inline `<script>` tags in templates.

## UI/UX

- Aim for polished, responsive interfaces: considered typography, spacing, and layout balance.
- Add subtle micro-interactions: hover effects, smooth transitions, loading states, page transitions.

## LiveView

- **Never** use `live_redirect` / `live_patch`. Use `<.link navigate={href}>` / `<.link patch={href}>` in templates and `push_navigate` / `push_patch` in LiveViews.
- **Avoid `LiveComponent`** unless there's a strong, specific need.

### Streams

Use LiveView streams for collections — regular list assigns balloon memory and can crash the runtime.

- Append: `stream(socket, :messages, [new_msg])`
- Reset (e.g. filter change): `stream(socket, :messages, msgs, reset: true)`
- Prepend: `stream(socket, :messages, [new_msg], at: -1)`
- Delete: `stream_delete(socket, :messages, msg)`

The parent needs a DOM id and `phx-update="stream"`; each child uses the stream id as its DOM id:

```heex
<div id="messages" phx-update="stream">
  <div :for={{id, msg} <- @streams.messages} id={id}>
    {msg.text}
  </div>
</div>
```

- Streams are **not enumerable** — no `Enum.filter`/`reject`. To filter, refetch and re-stream with `reset: true`.
- Streams don't support counting or empty states directly. Track counts in a separate assign. For empty states, use Tailwind — only works when the empty div is the **only** sibling of the for-comprehension:

  ```heex
  <div id="tasks" phx-update="stream">
    <div class="hidden only:block">No tasks yet</div>
    <div :for={{id, task} <- @streams.tasks} id={id}>{task.name}</div>
  </div>
  ```

- When an assign changes content inside streamed items, re-stream those items alongside the assign update (e.g. `stream_insert/3` before `assign/3`).
- **Never** use `phx-update="append"` / `"prepend"` — deprecated.

### JS hooks

- `phx-hook` requires a unique DOM id on the element.
- If the hook manages its own DOM, also set `phx-update="ignore"`.
- **Never** write raw `<script>` in HEEx. Use colocated hooks (names **must** start with `.`, auto-bundled into `app.js`):

  ```heex
  <input type="text" id="user-phone" phx-hook=".PhoneNumber" />
  <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
    export default {
      mounted() { /* ... */ }
    }
  </script>
  ```

- External hooks live in `assets/js/` and are passed to `LiveSocket`:

  ```js
  const MyHook = { mounted() { /* ... */ } }
  let liveSocket = new LiveSocket("/live", Socket, { hooks: { MyHook } })
  ```

### push_event / pushEvent

- Rebind or return the socket when pushing events:

  ```elixir
  socket = push_event(socket, "my_event", %{...})
  ```

- Client side:

  ```js
  this.handleEvent("my_event", data => { /* ... */ })
  this.pushEvent("my_event", { one: 1 }, reply => { /* ... */ })
  ```

- The server can reply: `{:reply, %{two: 2}, socket}`.
