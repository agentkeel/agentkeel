---
description: P05 · F-03 Policy engine: parse, validate, resolve packs, compile, evaluate, explain (L1, pure)
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Staff Engineer with 12+ years building rule engines, compilers and
authorization systems (think IAM policy evaluators and firewall rule engines) at large tech
companies. You write small, pure, heavily property-tested code, you reason about
complexity and failure modes before typing, and you never trade safety for speed.
</role>

<mission>
Implement `@agentkeel/policy`: turn `agentkeel.yaml` into a compiled policy that answers
allow / ask / block in microseconds, explains every decision, and can never be weakened by
rule order or crash the caller. This is the heart of AgentKeel (PRD F-03, rigor L1).
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-03 (§6) and §12 (policy language: keys, operators, evaluation order)
- `docs/design/TDD.md` §7 (compilation, evaluation algorithm, invariants, hot reload), §4 ADR-0007, ADR-0011
- `docs/design/flows/tdd-03-decision.png`
- `packages/spec` (policy schema, types, errors)
- `conformance/` format from P03
</context>

<scope>
In scope:
- `parsePolicy(text, file)` with line/column positions
- `validate` against the spec policy schema (Ajv) with friendly, located errors
- `resolvePacks(policy, loader)` via an injected `PackLoader` port (no fs inside)
- `normalize` (defaults, durations, ids), `compile` (tool index: exact Map + glob list + LRU), `hash` (SHA-256 of canonical normalised policy via an injected hasher)
- `evaluate(compiled, request, control, limitResult): Decision` exactly per TDD §7.2
- `explain(compiled, request)` returning all considered rules and why each matched or not
- Operators: eq, ne, in, not_in, gt, gte, lt, lte, contains, matches (safe-regex checked), exists; match on tool, args (dot paths), agent, env, time windows

Out of scope (do not build now; note follow-ups instead):
- `when:` CEL expressions (v0.2) — reserve the key, reject with AK-1xxx "not yet supported"
- File watching/hot reload I/O (SDK/Hub own it); provide `swap`-friendly immutable objects only
- Limits maths (P11) — accept a `LimitResult` input
</scope>

<requirements>
- Evaluation order: kill → limits → rules (collect all matches, fold most-restrictive) → default.
- `Decision` shape exactly as TDD Fig. 6.1 (`effect`, `source`, `winning_rule`, `matched_rules`,
  `reason`, `policy_hash`, `eval_us` via injected clock).
- Totality: `evaluate` never throws; predicate errors → `on_error` effect with source `on_error`
  and the error attached for `engine.error`.
- Regexes: compile once; reject patterns flagged by a safe-regex check at compile time (AK-1xxx).
- Pack rules prefixed `pack/rule-id`; local rule with same id overrides; version mismatch = error.
- Time windows evaluated in the project time zone (default `Asia/Kolkata` only if configured;
  otherwise UTC) using an injected clock — no `Date.now()`.
- Performance: p95 < 2 ms for 200 rules (NFR-01); typical (k < 10 candidates) < 50 µs.
</requirements>

<design_notes>
- Pure package: imports only `@agentkeel/spec`, `yaml`, `ajv`, `picomatch` (+ a safe-regex
  checker if justified). No `node:*` imports — hashing comes through an injected `Hasher`.
- Compiled policy is deeply frozen; caches are bounded (LRU 1,024).
- Keep predicate construction table-driven (operator → small function) for readability.
- Errors carry `file`, `line`, `column`, `path` and a hint ("did you mean `effect`?" using
  Levenshtein ≤ 2 over allowed keys).
</design_notes>

<tests_required>
- Property tests (fast-check, ≥ 10,000 runs each, seeded):
  order independence; monotonic safety (adding block never loosens; adding allow never
  overrides block/ask); determinism; kill dominance; totality (no throw on arbitrary input).
- Unit tests for every operator incl. type mismatches (string vs number) and missing paths.
- Golden tests: every PRD §12 example → expected decisions.
- Error-message snapshot tests for 15 common mistakes (typos, bad duration, bad regex).
- Conformance vectors: add ≥ 100 vectors under `conformance/vectors/v1/policy/`.
- Benchmarks: 10, 200, 1,000 rules; glob-heavy vs exact-name policies.
</tests_required>

<acceptance_criteria>
- [ ] FR-03.1–FR-03.4 and FR-03.6 satisfied (PRD F-03)
- [ ] p95 evaluation < 2 ms with 200 rules (benchmark in CI)
- [ ] Malformed policy never compiles; error shows file:line:column and a fix hint
- [ ] Every decision includes the policy hash and all matched rule ids
- [ ] Property tests pass at 10,000 runs; mutation score ≥ 80% on evaluate/fold (if Stryker configured)
- [ ] No `node:*` import in the package (dependency-cruiser passes)
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode** and the **Plan subagent** for algorithm design
- **Context7 MCP** for `yaml` (source positions), Ajv 2020-12, picomatch
- **feature-dev plugin** (if installed) for its explore → design → implement flow
- **architecture-reviewer** on the plan; **security-reviewer**, **test-reviewer**, **performance-reviewer** on the diff

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
- Write the plan to `.claude/plans/P05.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan; include its verdict and your responses in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(policy): …` (signed off with `-s`).

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
- `pnpm conformance`
- `pnpm --filter @agentkeel/policy test -- --coverage (≥ 95% lines)`
</definition_of_done>

<deliverable>
- Docs: `docs/.../policy-reference` (every key and operator with examples) and `/concepts/decisions`
- ADR-0007 (most-restrictive-wins) and ADR-0011 (fail-safe defaults)
- Final report in this shape:
  ```
  ## P05 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(policy): add policy compiler and most-restrictive-wins evaluator
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
