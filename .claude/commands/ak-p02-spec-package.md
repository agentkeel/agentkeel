---
description: P02 · Build @agentkeel/spec: event JSON Schemas, policy schema, Zod types, TypeIDs, error catalogue
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Principal API and Data-Contract Architect with 15+ years designing public
schemas and wire formats (CloudEvents producers, OpenAPI platforms, SDK generators) at
large tech companies. You know that a schema is a promise to thousands of users, so you
make it precise, versioned, minimal and impossible to misread.
</role>

<mission>
Create `@agentkeel/spec`, the single source of truth for every contract: the CloudEvents
envelope with AgentKeel extensions, every v0.1 event payload, the `agentkeel.yaml` policy
schema, TypeID helpers, shared value types and the error-code catalogue. Every other
package and the future Python SDK will be generated from or validated against it.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/EVENT-SCHEMA.md` (all of it)
- `docs/design/PRD.md` §12 (policy language), §16 (event model)
- `docs/design/TDD.md` §6 (domain model, TypeIDs), §14.1 (API conventions)
- `docs/design/flows/es-01-structure.png`, `docs/design/flows/es-02-chain.png`
</context>

<scope>
In scope:
- `schemas/v1/*.json` (JSON Schema 2020-12): `envelope.json`, `common.json`, one file per v0.1 event type
- `schemas/policy/v1.json` for `agentkeel.yaml` (strict: `additionalProperties: false`)
- Zod schemas mirroring the JSON Schemas + inferred TS types (and a test that both agree)
- TypeID helpers: `newId(prefix)`, `parseId`, `isId(prefix)`, UUIDv7 generation with monotonic counter
- Error catalogue `errors.ts`: code, title, docs URL; `AgentKeelError` base class
- `canonicalize()` (RFC 8785 JCS) re-export or tiny implementation with golden vectors

Out of scope (do not build now; note follow-ups instead):
- Events for v0.2+ (case.*, test.*, shadow.*) — add placeholders only if trivial
- OpenAPI generation (done in P07 with the Hub)
- Python model generation (v0.2)
</scope>

<requirements>
- Event types for v0.1: session.started/ended, action.requested, policy.decided,
  approval.requested/notified/decided/expired/cancelled/refused, action.executed/denied,
  action.result, limit.breached, kill.activated/released, policy.loaded/invalid,
  engine.error, chain.checkpoint, retention.pruned, data.purged, inventory.tools.
- Envelope rules exactly as EVENT-SCHEMA §4; collector-only fields (`akseq`, `akingested`,
  `akprevhash`, `akhash`) are optional in the producer schema and required in a separate
  `stored-envelope.json`.
- Payload field names snake_case; readers ignore unknown fields (`additionalProperties: true`
  for payloads, but required fields enforced).
- `$id` = `https://agentkeel.github.io/schemas/v1/<type>.json`; schemas immutable once released.
- Policy schema covers every key in PRD §12 including operators, durations ("10m", "1d"),
  `extends` entries (`name@major`), approvers, limits, redact, telemetry, plugins.
- Publish schemas inside the npm package (`files`) and export them by path.
</requirements>

<design_notes>
- Write JSON Schemas by hand (they are the public contract); write Zod by hand too and
  add a test that validates the same 200+ fixtures with Ajv and Zod and expects identical
  results — this catches drift.
- Fixtures: `fixtures/valid/*.json` and `fixtures/invalid/*.json` per type, including
  unknown-field and unknown-enum cases.
- TypeID: prefix + `_` + 26-char Crockford base32 of UUIDv7. Monotonic within a process.
- Errors: `AK-1xxx` policy, `AK-2xxx` approvals/API, `AK-3xxx` SDK, `AK-4xxx` store,
  `AK-5xxx` CLI, `AK-6xxx` MCP. Each has a docs URL `https://agentkeel.github.io/errors/AK-xxxx`.
</design_notes>

<tests_required>
- Ajv-vs-Zod agreement test over all fixtures.
- TypeID round-trip, ordering (ids sort by creation time), prefix validation, 1e5 uniqueness.
- JCS golden vectors (input JSON → exact canonical bytes → SHA-256), including unicode,
  numbers (1.0 vs 1), key ordering and nested arrays.
- Policy schema: every example in PRD §12 validates; typos like `efect` fail with a path.
</tests_required>

<acceptance_criteria>
- [ ] Every v0.1 event type has a JSON Schema, Zod schema, TS type and ≥ 2 valid + 2 invalid fixtures
- [ ] Example 4.1 and Example 14.1 from EVENT-SCHEMA validate
- [ ] PRD Example 12.1 policy validates; misspelled keys fail with a clear path
- [ ] TypeIDs are time-sortable and unique across 100,000 generations
- [ ] Error catalogue covers all codes referenced in PRD/TDD with docs URLs
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode**
- **Context7 MCP** for Ajv 2020-12 and Zod current APIs
- **architecture-reviewer** on the plan (this is a public contract)
- **test-reviewer** after implementation

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
- Write the plan to `.claude/plans/P02.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan against EVENT-SCHEMA §4 and §9; include its verdict in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(spec): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `architecture-reviewer` and `test-reviewer` subagents on your diff.
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
- `pnpm --filter @agentkeel/spec build`
</definition_of_done>

<deliverable>
- `packages/spec/README.md` explaining how to use the schemas
- ADR-0005 (CloudEvents envelope), ADR-0008 (TypeID), ADR-0017 (snake_case)
- Final report in this shape:
  ```
  ## P02 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(spec): add event and policy schemas, types and error catalogue
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
