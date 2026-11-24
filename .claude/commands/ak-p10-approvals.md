---
description: P10 · F-04 Approvals: state machine, compare-and-set, outbox, long-poll, Slack (Socket Mode) and Telegram notifiers
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Distributed-Systems Engineer with 12+ years building workflow engines,
payment approvals and notification pipelines. You model everything as explicit state
machines, make every write idempotent, and assume every network call can be retried,
duplicated or lost.
</role>

<mission>
Make `ask` real: an approval is created exactly once, delivered to Slack/Telegram/CLI/dashboard,
decided exactly once by an authorised person, and the waiting agent resumes within two
seconds — with every step recorded.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-04, §12 (approvers keys), §3.2 (journey B)
- `docs/design/TDD.md` §9 (creation, waiting, compare-and-set, notifier workers), §14 (endpoints), §15 (approvals, outbox tables), §18 (spoofing)
- `docs/design/flows/tdd-04-approval.png`
</context>

<scope>
In scope:
- `core`: approval state machine (pending → approved/rejected/expired/cancelled; refused attempts)
- Hub: `POST /v1/approvals` (Idempotency-Key = action id), `GET /v1/approvals/{id}?wait=25s`, `:decide` (If-Match), `:cancel`, timer worker for expiry
- Outbox worker with retries, backoff+jitter, dead state, per-channel circuit breaker, worker threads
- Notifiers: Slack (Bolt, Socket Mode, Block Kit, `chat.update` after decision), Telegram (grammY long-polling, inline keyboard, HMAC-signed callback data)
- SDK `ApprovalGateway` real implementation (long-poll, abort → cancel)
- CLI: `agentkeel approve|reject <id> [--comment]`, `agentkeel approvals` list

Out of scope (do not build now; note follow-ups instead):
- Email/webhook notifiers (v0.2)
- Dashboard inbox UI (P13 uses these APIs)
</scope>

<requirements>
- Exactly one decision wins under races (compare-and-set on version); losers get 409 with
  who decided and when.
- Only identities listed in the approver group may decide; `separate_approver` enforced;
  refused attempts recorded as `approval.refused`.
- Secrets (Slack app/bot tokens, Telegram bot token) only from env or keychain references
  (`env:SLACK_APP_TOKEN`), never in yaml or events.
- From click to agent resume < 2 s on a normal connection (FR-04 AC).
- Messages show agent, tool, redacted key args, rule id, reason, expiry and trace link.
</requirements>

<design_notes>
- State machine as a pure transition function `(state, event) → state | error` in `core`.
- Outbox rows written in the same transaction as the approval.
- Notifier plugin interface already matches TDD §20 (send/update/listen).
</design_notes>

<tests_required>
- State machine: exhaustive transition table test (every state × every event).
- Concurrency: 20 parallel decide calls → exactly one 200, others 409.
- Idempotent create under retries; expiry timer with fake clock; cancel on abort.
- Notifier tests against local fakes of Slack/Telegram APIs (no real network); forged
  Telegram callback rejected; unknown Slack user refused.
- E2E: SDK ask → CLI approve → tool runs; reject → denied + event.
</tests_required>

<acceptance_criteria>
- [ ] FR-04.1–FR-04.6 satisfied
- [ ] Race test: exactly one decision recorded
- [ ] Forged/unauthorised decisions refused and recorded
- [ ] Agent resumes < 2 s after decision (test with fake notifier)
- [ ] No token appears in logs/events (assertNoSecrets)
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode** + **Plan subagent**
- **Context7 MCP** for Slack Bolt Socket Mode, Block Kit, grammY
- **security-reviewer** (spoofing, replay), **architecture-reviewer**, **test-reviewer**

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
- Write the plan to `.claude/plans/P10.md` with:
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
- Run the `security-reviewer`, `architecture-reviewer` and `test-reviewer` subagents on your diff.
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
</definition_of_done>

<deliverable>
- Docs: guide "Human approvals" with Slack app manifest and Telegram BotFather steps
- ADR-0010 (outbox + compare-and-set)
- Final report in this shape:
  ```
  ## P10 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(hub): add approvals state machine with Slack, Telegram, CLI and API
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
