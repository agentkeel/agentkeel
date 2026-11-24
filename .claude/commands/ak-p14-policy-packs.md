---
description: P14 · F-06 Policy packs: coding-agent, mcp-baseline, email, payments — rules, tests, docs, versioning
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Security Engineer and Platform Policy Author with 10+ years writing
guardrail rule sets (cloud security baselines, CI hardening policies). You turn real
incidents into precise rules with few false positives, and every rule ships with tests
and a one-line explanation of the risk it addresses.
</role>

<mission>
Ship four reviewed, versioned policy packs so users are safe before writing a single rule,
with the built-in protection that agents can never edit AgentKeel's own policy or data.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-06, §12 (extends), §21 (approval fatigue risk)
- `docs/design/TDD.md` §7.1 (pack resolution), §18.1 (tampering threat: protected paths)
- `packages/policy` APIs
</context>

<scope>
In scope:
- `packs/coding-agent` (shell, git, filesystem): block `rm -rf /`-like commands, force push to protected branches, reading `.env`/keys, writing `agentkeel.yaml`/`.agentkeel/`; ask for `git push` to main, package publish, `curl | sh`
- `packs/mcp-baseline`: safe defaults for unknown MCP tools
- `packs/email`: external recipients ask; bulk sends ask; attachments rules
- `packs/payments`: refunds/transfers above thresholds ask; daily budgets
- Pack package layout, `name@major` versioning, README per pack, test cases per pack
- Built-in non-overridable protection rule for AgentKeel files (core, not a pack)

Out of scope (do not build now; note follow-ups instead):
- Community pack publishing docs beyond a short section (v0.2)
</scope>

<requirements>
- Each rule: id, effect, reason (short, human), risk note, ≥ 2 positive and ≥ 2 negative tests.
- Shell command matching must handle common evasions (extra spaces, `sudo`, `&&` chains,
  quoting) — document what is and is not covered.
- Keep `ask` rare: list expected approval rate assumptions in each README.
</requirements>

<design_notes>
- Packs are data (YAML) + tests; no code inside packs.
</design_notes>

<tests_required>
- Per-pack case tests run in CI; red-team style evasion cases for shell rules.
</tests_required>

<acceptance_criteria>
- [ ] FR-06.1–FR-06.3 satisfied
- [ ] coding-agent pack blocks `rm -rf /`, force push to protected branches and `.env` reads in tests
- [ ] Agents cannot modify `agentkeel.yaml` or `.agentkeel/` through guarded tools (test)
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Explore subagent** to collect real-world dangerous command patterns from docs
- **security-reviewer** (evasion), **test-reviewer**

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
- Write the plan to `.claude/plans/P14.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan; include its verdict and your responses in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(packs): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `security-reviewer` and `test-reviewer` subagents on your diff.
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
- `pnpm conformance`
</definition_of_done>

<deliverable>
- Docs: "Policy packs" page + one page per pack
- Final report in this shape:
  ```
  ## P14 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(packs): add coding-agent, mcp-baseline, email and payments policy packs
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
