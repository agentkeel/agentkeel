---
description: P07 · F-07 Event store + Keel Hub core: SQLite WAL store, ingest transaction, hash chain, projections, API v1 basics, SSE
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Principal Backend Engineer with 15+ years building event-sourced systems,
storage engines and high-throughput ingestion APIs at large tech companies. You design
transactions first, think in invariants (exactly-once storage, gapless sequence, verifiable
chain), and make APIs that are boring, standard and well documented.
</role>

<mission>
Build the Keel Hub process and its SQLite store so events from many agent processes are
stored exactly once, in a gapless hash-chained sequence, with projections updated in the
same transaction and pushed to live readers over SSE.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-07, F-08 (§7), NFR-03/05
- `docs/design/TDD.md` §3 (runtime processes), §11 (ingest), §14 (API design), §15 (database design), §16, §17
- `docs/design/EVENT-SCHEMA.md` §4, §8 (hash chain), §11 (bindings)
- `docs/design/flows/tdd-05-events.png`, `docs/design/flows/es-02-chain.png`, `docs/design/flows/tdd-10-deploy.png`
</context>

<scope>
In scope:
- `store-sqlite`: migrations (forward-only), PRAGMAs (WAL, NORMAL, busy_timeout, foreign_keys), STRICT tables from TDD §15.2 for v0.1
- `Store` port implementation: `appendEvents` (one transaction: dedupe, seq, chain, projections, outbox), queries with cursor pagination
- `hub`: Hono app on UDS/named pipe + 127.0.0.1:7471; middleware: request id, auth token, Host/Origin checks, RFC 9457 errors, idempotency keys, ETag
- Endpoints: `POST /v1/events:batch`, `GET /v1/events`, `GET /v1/traces/{id}`, `GET /v1/actions`, `GET /v1/stream` (SSE + Last-Event-ID), `/healthz`, `/readyz`, `/metrics`
- OpenAPI 3.1 document generated from Zod; served at `/v1/openapi.json`
- Spool drain on start and every 5 s; Hub discovery file `.agentkeel/run/hub.json`; real UDS Hub client for the SDK

Out of scope (do not build now; note follow-ups instead):
- Approvals endpoints (P10), kill/limits (P11), `verify`/checkpoints CLI (P12)
- Postgres store (v1.0)
- Dashboard UI (P13)
</scope>

<requirements>
- Hash: `akhash = SHA-256(prevhash || JCS(event without chain fields))`; genesis = 64 zeros.
- `akseq` gapless per project; client `time` kept, `akingested` authoritative for order.
- Batch ≤ 500 events / 1 MB; per-item results (accepted/duplicate/invalid); 429 + Retry-After.
- Throughput ≥ 2,000 events/s on a laptop with batches of 100 (NFR-03) — benchmark it.
- Security: token from `~/.agentkeel/token` (0600, generated if missing), UDS dir 0700,
  Host must be localhost/127.0.0.1, Origin must match for browser requests.
- Readiness only after migrations; Hub refuses to start on a newer schema than it knows.
- Structured logs via pino with a redaction serializer.
</requirements>

<design_notes>
- Hand-write SQL for the ingest hot path (prepared statements); Drizzle for other queries.
- `BEGIN IMMEDIATE` per batch; projections applied by small per-type functions (table-driven).
- SSE: in-process event emitter after commit; resume reads from store by seq.
- Idempotency keys table with 24 h TTL cleanup.
- Keep `hub` modules separated: `ingest/`, `query/`, `stream/`, `http/` (routes only call services).
</design_notes>

<tests_required>
- Ingest: duplicates stored once; seq gapless under 8 concurrent writers; chain verifies;
  crash mid-transaction (kill child process) leaves a consistent db.
- API contract tests: OpenAPI vs responses (Schemathesis if available, else schema checks).
- Security tests: wrong token 401; bad Host 421/403; cross-origin browser request blocked.
- SSE: resume with Last-Event-ID delivers every missed event exactly once.
- Spool drain idempotency.
- Benchmarks: ingest throughput and p95 batch latency.
</tests_required>

<acceptance_criteria>
- [ ] FR-07.1–FR-07.5 satisfied
- [ ] 10,000-action run records 100% of events with no gaps (test)
- [ ] Ingest ≥ 2,000 events/s locally (benchmark recorded)
- [ ] Hash chain verifies over stored events (unit-level verify function)
- [ ] OpenAPI document generated and valid
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode** + **Plan subagent**
- **Context7 MCP** for Hono, @hono/node-server (unix socket), better-sqlite3, Drizzle, pino
- **architecture-reviewer** on the plan; **security-reviewer**, **performance-reviewer**, **test-reviewer** on the diff

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
- Write the plan to `.claude/plans/P07.md` with:
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
- Run the `security-reviewer`, `performance-reviewer`, `architecture-reviewer` and `test-reviewer` subagents on your diff.
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
- `pnpm --filter @agentkeel/hub test -- --coverage (≥ 85%)`
</definition_of_done>

<deliverable>
- Docs: "How events are stored", API reference generated from OpenAPI, Hub page
- ADR-0003 (SQLite/Postgres), ADR-0004 (events as source of truth), ADR-0006 (single writer + chain), ADR-0009 (REST + OpenAPI + RFC 9457), ADR-0015 (Hono), ADR-0018 (localhost hardening)
- Final report in this shape:
  ```
  ## P07 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(hub): add Keel Hub with SQLite event store, ingest and hash chain
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
