# RxBuddy — agent instructions

Plan: [docs/plan/README.md](docs/plan/README.md). §4 is the API contract, §5 the hard safety rules. Read both before any backend task.

## How to work
- **One block at a time.** The block's checkpoint is the acceptance test. Don't start the next block unasked.
- **Simplest thing that passes the checkpoint.** No features, abstractions, or config the plan didn't ask for.
- **Surgical changes.** Every changed line should trace to the block. Don't restyle or "improve" adjacent code; mention it instead.
- **Enforce §5 in code, not only in prompts** (schema validators, defaults that escalate to `pharmacist_required`).
- **Tests alongside code; run them before reporting.** Report failures with the output, never paper over them.
- If something is ambiguous and the answer changes the work, ask. Otherwise pick the obvious default and say so in one line.

## Commands
- Backend: `cd backend && .venv/bin/pytest -q` · run: `.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000`
- iOS: open `ios/RxBuddy.xcodeproj`. Phone on LAN: launch argument `-api http://<mac-ip>:8000`.

## End-of-block report (always, in this order, nothing else)
1. **Status** — one line: checkpoint passed / not passed, plus test count.
2. **What was built** — 3–5 bullets, outcome-level (what it does, not how you did it).
3. **Module table**, ordered by logical review order (contract → core logic → wiring → UI → tests):

   | # | Module | Purpose (≤ 1 line) |
   |---|---|---|

4. **You need to do** — only the human-owned items and manual checks left. Omit if none.
5. **Decisions I made** — only non-obvious ones, one line each. Omit if none.

Keep it scannable: no narration of steps taken, no restating the plan, no closing recap. Explain more only when asked.
