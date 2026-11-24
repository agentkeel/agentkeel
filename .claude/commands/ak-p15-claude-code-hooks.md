---
description: P15 · F-18 Claude Code hooks: agentkeel hooks install, PreToolUse/PostToolUse client, ask via Hub approvals
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Developer-Tools Integration Engineer with 10+ years building editor
and agent integrations (IDE extensions, git hooks, CLI plugins). You follow the host tool's
documented contracts exactly, keep hook latency tiny and make install/uninstall safe.
</role>

<mission>
Protect Claude Code itself: every tool use passes through AgentKeel via official hooks, with
fast decisions, human approvals for `ask`, and a clean install/uninstall experience.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-18 (Claude Code part), §3.1
- `docs/design/TDD.md` §13.2
- Current official Claude Code hooks documentation (input JSON on stdin, output format, exit codes, timeouts) — fetch via Context7 or docs; do not rely on memory
</context>

<scope>
In scope:
- `agentkeel hooks install|uninstall [--project|--user]` editing Claude Code settings JSON safely (backup, idempotent, preserves other hooks)
- `agentkeel hook pre` / `hook post`: tiny entry points (fast startup), read JSON from stdin, call Hub `POST /v1/decisions`, print the documented decision output
- Ask: wait for Hub approval up to the configured hook timeout; then deny with reason
- Hub unreachable → on_error (default deny) with a message telling the user how to start the Hub

Out of scope (do not build now; note follow-ups instead):
- Other framework adapters (v0.2+)
</scope>

<requirements>
- Hook startup + decision p95 < 150 ms excluding approval wait.
- Never corrupt the user's settings file (atomic write, JSON validation, backup).
- Tool name mapping documented (Bash, Edit, Write, MCP tools…).
</requirements>

<design_notes>
- Separate tiny `hook` bin with minimal imports; reuse Hub client from SDK.
</design_notes>

<tests_required>
- Settings editing with existing hooks, comments-free JSON, invalid JSON (refuse, explain).
- Golden I/O tests for pre/post hook payloads per documented schema.
- E2E with a fake Claude Code invocation script.
</tests_required>

<acceptance_criteria>
- [ ] Claude Code blocked from `rm -rf` and `.env` reads with the coding-agent pack (manual check documented with screenshots)
- [ ] Install/uninstall round-trip leaves settings identical
- [ ] Latency budget met
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Context7 MCP** / docs fetch for Claude Code hooks reference
- **hookify plugin** (if installed) only as a reference for hook formats
- **security-reviewer**, **test-reviewer**

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
- Write the plan to `.claude/plans/P15.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Ask the `architecture-reviewer` subagent to review the plan; include its verdict and your responses in the plan file.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(adapters): …` (signed off with `-s`).

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
</definition_of_done>

<deliverable>
- Docs: guide "Protect Claude Code" (this is a launch headline — make it excellent)
- Enable it on this repository (dogfooding) and note it in CONTRIBUTING
- Final report in this shape:
  ```
  ## P15 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(adapters): add Claude Code hooks integration
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
