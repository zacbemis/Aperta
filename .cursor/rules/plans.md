---
applyIntelligently: true
---

# Plans

Plans live in `.cursor/plans/` and describe multi-step work.

## Executing a plan

- Do **one step at a time** — stop after each so the user can review before moving on.
- At the end of every step, run the test suite (`mix test`) and fix regressions before continuing.
