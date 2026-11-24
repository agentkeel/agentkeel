---
description: P03 · Build the shared test harness: benchmarks with CI comparison, conformance vectors, redaction corpus, fault injection
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Test Infrastructure Engineer with 12+ years building test platforms
for performance- and safety-critical libraries (databases, runtimes, payment SDKs). You
make benchmarks statistically honest, test data realistic and failures reproducible.
</role>

<mission>
Give every later feature the tools to prove it is correct and fast: a benchmark runner
with a "compare against main" gate, a conformance-vector format shared by TypeScript and
(later) Python, a redaction test corpus of fake secrets, and a fault-injection helper.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/SDLC.md` §7 (testing strategy), §8 (CI)
- `docs/design/PRD.md` §17 (NFRs)
- `docs/design/TDD.md` §16 (performance), §17 (failure modes)
</context>

<scope>
In scope:
- `packages/testkit-internal` (private): bench runner wrapper (mitata or tinybench), JSON results, comparison script with 20% regression gate and noise handling
- `conformance/` folder: YAML vector format `{ policy, request, control, expect }` + runner stub
- `fixtures/redaction-corpus/`: fake API keys (common formats), JWTs, emails, Indian and international phone numbers, Luhn-valid card numbers, private-key blocks — all FAKE
- Fault injection helpers: failing clock, failing store, slow notifier, disk-full simulation
- `pnpm bench`, `pnpm bench:compare`, `pnpm conformance` wired to real implementations

Out of scope (do not build now; note follow-ups instead):
- Benchmarks of features that do not exist yet (add examples only)
- Mutation testing setup (add later for L1 packages)
</scope>

<requirements>
- Bench compare: run N iterations, discard warm-up, compare medians and p95 with a
  noise threshold; output Markdown table usable in a PR comment; exit 1 on > 20% regression.
- Results stored as JSON artefacts; `main` baseline fetched from CI artefact or computed.
- Redaction corpus: each item labelled with its kind; a helper `assertNoSecrets(text)` fails
  if any corpus value appears in a string (used by every package that stores data).
- Conformance vectors versioned (`vectors/v1/*.yaml`), schema-validated, IDs stable.
</requirements>

<design_notes>
- Keep this package private and dependency-light; it is dev tooling.
- Make bench output deterministic in format so diffs are readable.
- Fake secrets must not trigger GitHub push protection: build them from parts at runtime
  or use formats documented as test values; document this in the corpus README.
</design_notes>

<tests_required>
- Comparison script unit tests (regression detected, noise ignored, missing baseline handled).
- `assertNoSecrets` detects every corpus item and has zero false positives on 50 normal strings.
- Conformance runner validates vector files and reports clear diffs.
</tests_required>

<acceptance_criteria>
- [ ] `pnpm bench:compare` prints a table and fails on an injected 30% slowdown
- [ ] `assertNoSecrets` catches all corpus items
- [ ] Conformance runner executes an example vector set
- [ ] Secret scanners in CI (trufflehog) do not flag the corpus
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode**
- **Context7 MCP** for mitata/tinybench APIs
- **test-reviewer** subagent

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
- Write the plan to `.claude/plans/P03.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan; include its verdict and your responses in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(build): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `test-reviewer` subagent on your diff.
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
- `pnpm bench:compare`
- `pnpm conformance`
</definition_of_done>

<deliverable>
- `conformance/README.md` (vector format)
- Section in CONTRIBUTING on benchmarks and the redaction corpus
- Final report in this shape:
  ```
  ## P03 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: test: add benchmark, conformance and redaction-corpus harness
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
