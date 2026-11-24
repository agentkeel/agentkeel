---
description: P04 · Create the docs site (Astro Starlight → GitHub Pages) with information architecture and first pages
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Developer Advocate and Docs Engineer with 10+ years building
documentation for popular open-source developer tools. You design docs around user jobs,
write short concrete sentences for a global audience, and treat docs as code.
</role>

<mission>
Create agentkeel.github.io as a Starlight site in `docs/` with the full information
architecture, a landing page that explains the loop in 30 seconds, and stub pages for every
v0.1 feature, so each feature PR only has to fill its page.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` §2, §3 (journeys), §14 (CLI), §18 (DX)
- `docs/design/SDLC.md` §14 (documentation workflow)
- `README.md`
- `.github/workflows/docs.yml`
</context>

<scope>
In scope:
- `docs/` Astro Starlight project (workspace package `docs`, private)
- Sidebar: Get started · Concepts (the loop) · Guides (per feature) · Policy reference · CLI reference · API reference · Errors · Security · Contributing
- Landing page, Quick start (marked "coming with v0.1"), Concepts page with the loop diagram
- `/errors/AK-xxxx` page template generated from the spec error catalogue
- Brand: AgentKeel logo, navy/orange accents, Inter + JetBrains Mono self-hosted, dark mode

Out of scope (do not build now; note follow-ups instead):
- Writing full feature guides (each feature prompt does that)
- Custom domain
</scope>

<requirements>
- Builds with `pnpm --filter docs build` to `docs/dist`; deploy workflow already exists.
- `site` = `https://agentkeel.github.io`; no external analytics or fonts.
- Link checking in CI (Starlight link validator or equivalent).
- Every page has front-matter description for search and social cards.
</requirements>

<design_notes>
- Information architecture follows user jobs (PRD §3 journeys), not package names.
- Error pages are generated so new codes cannot ship without a page.
</design_notes>

<tests_required>
- Build succeeds; link check passes; error page generation test (one page per catalogue code).
</tests_required>

<acceptance_criteria>
- [ ] Docs build locally and in CI
- [ ] Every v0.1 feature has a stub page linked in the sidebar
- [ ] Error pages generated for all catalogue codes
- [ ] Lighthouse accessibility ≥ 95 on landing page (Playwright MCP check)
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **Context7 MCP** for Astro Starlight configuration
- **Playwright MCP** to open the built site and check pages and accessibility
- **frontend-design skill/plugin** for the landing page layout
- **docs-reviewer** subagent

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
- Write the plan to `.claude/plans/P04.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Show the sidebar structure in the plan.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(docs): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `docs-reviewer` subagent on your diff.
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
- `pnpm --filter docs build`
- `pnpm lint`
</definition_of_done>

<deliverable>
- README link to the docs site
- Short "How to write docs" page in Contributing section
- Final report in this shape:
  ```
  ## P04 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: docs: add Starlight documentation site skeleton
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
