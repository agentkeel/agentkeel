---
description: P11 · F-05 Kill switch and limits: control stream (SSE), budgets with reservations, sliding-window rate limits, loop detection
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Reliability Engineer with 12+ years building rate limiters, quota
systems and emergency stop mechanisms for large-scale APIs. You think about clocks,
windows, leases and crash recovery, and you test the bad day, not the happy path.
</role>

<mission>
Give operators hard stops that work across every agent process: a kill switch that blocks
the next action within one second, budgets that many processes cannot overspend together,
rate limits, and loop detection.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-05, §12 (limits keys)
- `docs/design/TDD.md` §8.2 (control snapshot), §10 (kill + limits algorithms), §15 (tables)
- `docs/design/flows/tdd-06-control.png`
</context>

<scope>
In scope:
- Hub: kill switch tables/endpoints (`POST /v1/kill-switches`, `:release`), `GET /v1/control` + `/v1/control/stream` (SSE with control_version)
- SDK: control snapshot subscription, 1 s poll fallback, stale detection (`on_control_stale`)
- Limits: budgets (fixed windows in project TZ) with reservations + 60 s leases + settle/release; rate limits (sliding window approximation); loop detection (same tool+args hash N times in M s)
- CLI: `agentkeel kill [--agent|--tool] --reason`, `agentkeel resume`
- Kill cancels in-flight approvals in scope

Out of scope (do not build now; note follow-ups instead):
- Slack/Telegram `/ak kill` commands (follow-up issue)
- Dashboard button (P13)
</scope>

<requirements>
- Kill effective on next action within 1 s (measure in test); survives restarts.
- Reservation is atomic (compare-and-add); released on denial/failure; expired leases freed.
- Only actions matching a limit call the Hub; others stay on the fast path.
- All times from the injected clock; window alignment documented.
</requirements>

<design_notes>
- Limit maths pure in `core` (window keys, sliding estimate); persistence in store.
- Control versions monotonically increasing; SDK ignores older versions.
</design_notes>

<tests_required>
- Kill latency test; persistence across Hub restart; scope matching (all/agent/tool glob).
- Budget concurrency: 10 processes × 100 reservations never exceed max.
- Lease expiry; settle vs release; window boundary cases (23:59:59 → 00:00:00 IST).
- Loop detection on a scripted looping agent.
</tests_required>

<acceptance_criteria>
- [ ] FR-05.1–FR-05.4 satisfied
- [ ] No overspend under concurrency (property/stress test)
- [ ] Stale control flagged on events and handled per config
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode**
- **Context7 MCP** for SSE handling in Hono
- **security-reviewer**, **test-reviewer**, **performance-reviewer**

If a tool above is not installed or not available, continue without it and use the
plain alternative (read files, run commands). Never stop only because a tool is missing.
Mention in your final report which tools you used.
</tools>

<workflow>
Work in these phases. Do not skip or merge phases. Stop where it says STOP.

**Phase 1 — Understand (read, do not write code)**
- Read every file in <context>, completely. Open the PNG flows; they are part of the spec.
- Use the Explore subagent for any wide search so the main context stays small.
- Write back, in 5–10 bullets: the goal, the public surface you will create or change,
  and every ambiguity or conflict you found between documents and code.

**Phase 2 — Plan, then STOP**
- Write the plan to `.claude/plans/P11.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan; include its verdict and your responses in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(hub): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `security-reviewer`, `test-reviewer` and `performance-reviewer` subagents on your diff.
- Fix every finding rated critical/high/must-fix. List the rest with your reasoning.

**Phase 7 — Docs**
- Update the docs listed in <deliverable>. Make error messages helpful
  (what happened · why · how to fix · docs link).

**Phase 8 — Hand-off (no push, no PR unless I ask)**
- Reply with the report described in <deliverable>.
</workflow>

<quality_bar>
- Follow `CLAUDE.md` exactly: fail safe, redaction before storage, most-restrictive-wins,
  pure `policy`/`core`, snake_case wire format, TypeIDs, AK-xxxx error codes.
- TypeScript strict; no `any`, no non-null assertions without a comment proving safety;
  explicit return types on exports; TSDoc on every export.
- Small functions with single responsibility; names that explain intent; comments explain why.
- Every error path is tested. Every invariant has a property test (L1) or explicit test (L2/L3).
- Deterministic tests: inject `Clock`, seed randomness, no real network (use local fakes).
- No new runtime dependency unless justified in the plan and approved.
- Do not touch files outside <scope>. If you must, stop and ask.
- Verify library APIs with Context7 (or `node_modules` source) instead of memory.
</quality_bar>

<definition_of_done>
- `pnpm lint`
- `pnpm typecheck`
- `pnpm test`
- `pnpm bench`
</definition_of_done>

<deliverable>
- Docs: guide "Kill switch, budgets and rate limits"
- Final report in this shape:
  ```
  ## P11 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(hub): add kill switch, budgets, rate limits and loop detection
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
