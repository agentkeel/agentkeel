---
description: P06 · F-01 TypeScript SDK: guard()/guardAll(), redaction, decision pipeline, ring buffer, spool, Hub client stub
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Principal SDK Engineer with 12+ years designing developer SDKs used by
millions (payments, observability and cloud SDKs). You design APIs that are obvious in two
lines, impossible to misuse, never crash the host application, and degrade gracefully when
the network or backend is down.
</role>

<mission>
Implement `@agentkeel/sdk` so a developer protects every tool with one line, every call
goes through the decision pipeline in-process, and every event reaches the Hub (or the
spool when the Hub is unavailable) without ever slowing or crashing the agent.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-01 (§6), §13 (privacy/redaction)
- `docs/design/TDD.md` §3.3 (Hub discovery), §5.1 (ports), §8 (guard pseudo-code, buffer, spool, control snapshot), §17 (failure modes)
- `docs/design/EVENT-SCHEMA.md` §7.1–7.4, §10 (redaction)
- `docs/design/flows/tdd-03-decision.png`, `docs/design/flows/tdd-05-events.png`
- `packages/policy`, `packages/core`, `packages/spec`
</context>

<scope>
In scope:
- `core`: decision pipeline orchestration, redaction engine (key + value detectors, HMAC markers), ports
- `sdk`: `guard(tool, opts)`, `guardAll(tools, opts)`, `AgentKeelDenied`, context (agent, version, session, tags), `onDeny: "return" | "throw"`
- Ring buffer with priority classes, batching flush (200 ms / 100 events), gzip, backoff with full jitter, circuit breaker
- Spool writer (JSONL, fsync per batch, rotation 8 MB) and shutdown flush (2 s deadline)
- Policy file loading + watching (debounced, atomic swap, `policy.loaded`/`policy.invalid` events)
- Hub client interface + in-memory fake (real HTTP over UDS comes with P07/P08)
- Control snapshot port with stale detection

Out of scope (do not build now; note follow-ups instead):
- Approvals waiting (P10) — `ask` resolves via an `ApprovalGateway` port; default implementation returns `on_error`
- Limits (P11) — `LimitGateway` port with a no-op default
- Framework adapters (P15, v0.2)
</scope>

<requirements>
- Two-line quick start: `import { guardAll } from "@agentkeel/sdk"; const tools = guardAll({ refund, search });`
- A blocked/denied tool function is never invoked (FR-01.3) — enforce structurally.
- Tool errors pass through unchanged after recording `action.result` (status error).
- Redaction before anything is emitted; HMAC markers use a per-project salt from config.
- Critical events (requested, decided, denied, approval.*, engine.error) are never dropped:
  if the buffer is full they are appended synchronously to the spool.
- Overhead budget: p95 < 2 ms total in-process with 200 rules (NFR-01).
- ESM + CJS + types; works on Node 22/24 and Bun (no Node-only APIs on the hot path).
</requirements>

<design_notes>
- Keep `guard()` thin: build request → pipeline → act; all logic in `core` for reuse by Hub.
- Use `AbortSignal` support on tools that accept a context argument.
- Shadow mode flag exists in options (`mode: "shadow"`) and denies side-effect tools
  (full shadow behaviour arrives in v0.3, but the safety rule is enforced now: ADR-0014).
- No global singletons that break tests: expose `createAgentKeel(config)`; `guard` uses a
  default instance created lazily.
</design_notes>

<tests_required>
- Unit: allow passthrough equality; block never calls tool (spy); ask → on_error default;
  engine throw → on_error + engine.error; tool throw → rethrown and recorded.
- Redaction: corpus from P03 — `assertNoSecrets` over every emitted event in tests.
- Buffer: priority, overflow to spool, ordering, flush on shutdown, backoff timings (fake clock).
- Spool: crash mid-write recovery (truncated last line ignored), rotation.
- Hot reload: valid change swaps; invalid change keeps last good and emits policy.invalid.
- Benchmarks: guard overhead with 10/200 rules; redaction on 1 KB and 32 KB args.
</tests_required>

<acceptance_criteria>
- [ ] FR-01.1–FR-01.7 satisfied
- [ ] Quick start in README works exactly as written (test it)
- [ ] Zero secrets from the corpus appear in any emitted event
- [ ] Killing the process loses at most 1 s of normal events and no critical events (test with child process)
- [ ] Bundle size within the size-limit budget
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode**
- **Context7 MCP** for Node stream/fs APIs, zlib, Bun compatibility notes
- **feature-dev plugin** (if installed)
- **security-reviewer**, **performance-reviewer**, **test-reviewer** subagents

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
- Write the plan to `.claude/plans/P06.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan; include its verdict and your responses in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(sdk): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `security-reviewer`, `performance-reviewer` and `test-reviewer` subagents on your diff.
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
- `pnpm size`
</definition_of_done>

<deliverable>
- Docs: Quick start (SDK), guide "Protect your tools", redaction page
- README code sample updated if the API changed
- Final report in this shape:
  ```
  ## P06 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(sdk): add guard() with redaction, event buffer and spool
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
