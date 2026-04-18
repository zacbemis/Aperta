---
applyIntelligently: true
---

# Tests

## General

- **Use `start_supervised!/1`** to start processes in tests — it guarantees cleanup between tests.
- **Never** use `Process.sleep/1` or `Process.alive?/1` in tests.
  - To wait for a process to exit, use `Process.monitor/1` and assert on `:DOWN`:

    ```elixir
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    ```

  - To synchronize before the next call, use `_ = :sys.get_state(pid)` so prior messages have been handled.
- Debug failures with `mix test path/to/file.exs` (single file) or `mix test --failed` (rerun previously failed).

## LiveView tests

- Use `Phoenix.LiveViewTest` + `LazyHTML` (both already included) for assertions.
- Form tests use `render_submit/2` and `render_change/2`.
- **Always** assert via `element/2`, `has_element?/2`, etc. — never against raw HTML strings.
- Reference the unique DOM IDs you set on forms/buttons/etc. (`<.form id="todo-form">` → `has_element?(view, "#todo-form")`).
- Prefer asserting on key elements over text content — text changes more often than structure.
- Test outcomes, not implementation details. `Phoenix.Component`'s `<.form>` may produce different HTML than you expect — assert against the actual output.
- When a selector fails, debug with `LazyHTML` filters rather than dumping the whole page:

  ```elixir
  html = render(view)
  document = LazyHTML.from_fragment(html)
  matches = LazyHTML.filter(document, "your-complex-selector")
  IO.inspect(matches, label: "Matches")
  ```

- Plan tests as small, isolated files. Start with content-exists assertions, then layer in interaction tests.
