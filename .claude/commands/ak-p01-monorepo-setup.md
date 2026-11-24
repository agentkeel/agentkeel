---
description: P01 · Set up the AgentKeel monorepo skeleton (pnpm, Turborepo, TypeScript, Biome, Vitest, lefthook)
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Staff Platform / DevOps Engineer with 12+ years of experience building and
maintaining large TypeScript monorepos for open-source projects and big tech companies.
You have set up pnpm + Turborepo workspaces used by hundreds of contributors, you obsess
over fast feedback loops, reproducible builds and least-privilege CI, and you keep tooling
boringly simple so first-time contributors succeed on the first try.
</role>

<mission>
Create the empty-but-production-ready monorepo that every later feature will live in.
After this task a new contributor can clone the repo, run three commands and get a green
build, lint, typecheck and test on Linux, macOS and Windows.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/SDLC.md` §4 (repository layout), §6 (code quality), §8 (CI)
- `docs/design/TECH-STACK.md` §4 (monorepo tooling)
- `docs/design/TDD.md` §5 (package design and layering)
- `.github/workflows/ci.yml` (already in the repo — CI expects the scripts below)
- `docs/design/flows/tdd-02-containers.png`
</context>

<scope>
In scope:
- Root `package.json` (private, `packageManager` pinned via corepack, `engines.node >=22`)
- `pnpm-workspace.yaml`, `turbo.json`, root `tsconfig.base.json` + per-package `tsconfig.json` with project references
- Biome config, dependency-cruiser config with the layering rules, lefthook + commitlint wiring
- Vitest workspace config with coverage (v8) thresholds per rigor level
- Empty packages with `src/index.ts`, README and one smoke test: `spec`, `policy`, `core`, `sdk`, `hub`, `store-sqlite`, `mcp-proxy`, `cli` (npm name `agentkeel`, bin `agentkeel`), `dashboard` (placeholder)
- tsup build config (ESM + CJS + d.ts) for libraries; size-limit config for `sdk` (< 200 KB)
- Root scripts: `build`, `test`, `test:watch`, `lint`, `typecheck`, `bench`, `bench:compare`, `size`, `conformance`, `dev`

Out of scope (do not build now; note follow-ups instead):
- Any product logic
- Docs site (P04)
- Python SDK (v0.2)
- Changing workflow files except to align script names (ask first)
</scope>

<requirements>
- Node 22 and 24 must both work; no Node-only APIs that break Bun in `sdk` later.
- `pnpm install --frozen-lockfile` must work in CI; commit `pnpm-lock.yaml`.
- Package names: `@agentkeel/spec`, `@agentkeel/policy`, `@agentkeel/core`, `@agentkeel/sdk`,
  `@agentkeel/hub`, `@agentkeel/store-sqlite`, `@agentkeel/mcp-proxy`, `@agentkeel/dashboard`
  (private for now), and the CLI package published as `agentkeel` (currently 0.0.1 on npm).
- Every publishable package: `"license": "Apache-2.0"`, `repository`, `homepage`, `files`,
  `exports` map with `types` first, `sideEffects: false` where true, `publishConfig.access: public`.
- dependency-cruiser rules: `policy` may import only `spec`; `core` only `spec` and `policy`;
  nothing in `policy`/`core` may import `node:*`, `fs`, `net`, `http`, `child_process`.
- Coverage thresholds: policy/core 95%, sdk/hub/store/mcp 85%, cli/dashboard 75%.
- `pnpm bench` and `pnpm conformance` may be placeholders that print "no benchmarks yet"
  and exit 0, but the scripts must exist (P03 fills them).
</requirements>

<design_notes>
- Use TypeScript project references so `tsc --build` is incremental.
- Turborepo pipeline: `build` depends on `^build`; `test` and `typecheck` depend on `^build`
  only where needed; cache outputs `dist/**`, `coverage/**`.
- Keep root devDependencies minimal; prefer one tool per job (Biome instead of ESLint+Prettier).
- Add `.vscode/extensions.json` recommending Biome and Vitest extensions.
</design_notes>

<tests_required>
- One smoke test per package (imports the entry point).
- A test that runs dependency-cruiser on a fixture violating the layering rules and
  expects failure (proves the guard works).
</tests_required>

<acceptance_criteria>
- [ ] `pnpm i && pnpm build && pnpm lint && pnpm typecheck && pnpm test` passes from a clean clone
- [ ] A deliberate import of `node:fs` inside `packages/policy` makes `pnpm lint` fail
- [ ] CI workflow `ci.yml` runs its Node jobs (lockfile exists) and `ci-ok` is green
- [ ] `pnpm size` reports the sdk budget
- [ ] README "Development" section matches the real commands
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Plan mode** for Phase 2
- **Explore subagent** to read the existing workflow files
- **Context7 MCP** for current pnpm, Turborepo, Biome, Vitest, tsup and dependency-cruiser config syntax
- **architecture-reviewer** subagent on the plan

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
- Write the plan to `.claude/plans/P01.md` with:
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
- Run the `architecture-reviewer` subagent on the diff (layering, package boundaries).
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
- `pnpm build`
- `pnpm size`
- Fresh clone test: `git clone` into a temp dir and run the five commands
</definition_of_done>

<deliverable>
- Update `CONTRIBUTING.md` "Development setup" if commands differ
- Add ADR-0001 (monorepo + hexagonal packages) using `adr/0000-template.md`
- Final report in this shape:
  ```
  ## P01 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: build: set up pnpm + Turborepo monorepo skeleton
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
