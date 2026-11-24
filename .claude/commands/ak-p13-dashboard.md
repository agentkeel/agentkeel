---
description: P13 · F-09 Local dashboard: Vite + React SPA served by the Hub, live feed, trace view, approvals inbox, policies, kill switch
argument-hint: "[optional notes or constraints for this run]"
---

<role>
You are a Senior Frontend Engineer and Product Designer with 10+ years building
developer-facing dashboards (observability, CI, cloud consoles) at top product companies.
You design for clarity under stress, accessibility (WCAG 2.1 AA) and speed, and you build
with typed data layers and virtualised lists.
</role>

<mission>
Ship the local dashboard that makes the loop visible: what agents are doing right now,
the full story of any action, pending approvals, active rules and the kill switch — fast,
accessible, offline and on-brand.
</mission>

<context>
Read these before anything else:
- `CLAUDE.md`
- `docs/design/PRD.md` F-09, §15 (screens, UX rules)
- `docs/design/TDD.md` §21 (dashboard architecture), §14 (API), §14.2 (auth: one-time URL → cookie)
- Brand: AgentKeel logo (repo root), navy `#0F172A` + orange `#EA580C` accents, Inter + JetBrains Mono (self-hosted)
- OpenAPI document from the Hub (`/v1/openapi.json`)
</context>

<scope>
In scope:
- Screens: Home, Activity, Trace, Approvals, Policies, Settings (Cases/Tests/Shadow placeholders hidden behind flags)
- Typed API client generated from OpenAPI; TanStack Query; SSE live updates; URL-state filters (TanStack Router)
- Accessible components (shadcn/ui on Radix); light/dark themes; empty states that teach
- Kill switch with confirmation; approve/reject with comment; "explain" panel
- Build to static files bundled into the CLI and served by the Hub at `/`

Out of scope (do not build now; note follow-ups instead):
- Cases, Tests, Shadow screens (v0.2/v0.3)
- Server-mode login (v1.0)
</scope>

<requirements>
- Initial JS < 250 KB gzip; first load < 1.5 s on localhost; feed handles 10,000 rows smoothly.
- Never show unredacted data (dashboard only renders what the API returns).
- Status never by colour alone; keyboard navigation for all actions; focus visible.
- No external network requests (fonts, CDNs, analytics) — assert in e2e.
</requirements>

<design_notes>
- Feature folders per screen; data hooks per resource; no global state beyond Query cache.
- Design tokens shared with docs site; reuse logo assets.
</design_notes>

<tests_required>
- Component tests for key widgets; Playwright e2e: approve flow, kill flow, trace view, filters
  via URL, SSE live update; axe accessibility checks on every screen; no external requests.
- Visual screenshots at 1280 and 768 widths for README.
</tests_required>

<acceptance_criteria>
- [ ] FR-09.1–FR-09.6 satisfied
- [ ] axe: zero serious/critical violations
- [ ] Feed shows a new action within 1 s; trace loads < 500 ms for 1,000 events
- [ ] Zero external network requests
</acceptance_criteria>

<tools>
Use these Claude Code capabilities when they help:
- **frontend-design plugin/skill** for layout and visual polish
- **Playwright MCP** to drive the real UI, take screenshots and check accessibility
- **Context7 MCP** for TanStack Router/Query, Tailwind, shadcn/ui
- **docs-reviewer** for UI copy, **test-reviewer**

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
- Write the plan to `.claude/plans/P13.md` with:
  1. files to create/change, each with one line of purpose;
  2. public interfaces with full TypeScript signatures;
  3. data structures and algorithms, with complexity where it matters;
  4. the test list (name → what it proves → which acceptance criterion);
  5. risks and how you will handle each; new dependencies with justification (or "none").
- Include low-fidelity wireframes (ASCII or Markdown) for each screen in the plan and ask the `architecture-reviewer` to check the data flow.
- **STOP. Show me the plan and wait until I reply "approved" (or give changes).**

**Phase 3 — Tests first**
- Write the tests from the plan. Run them. Confirm they fail for the expected reason.
- Commit: `test(dashboard): …` (signed off with `-s`).

**Phase 4 — Implement in small steps**
- Make one test group pass at a time; run the affected tests after every step.
- Keep each commit focused and buildable. Never change a test only to make it pass;
  if a test is wrong, stop and explain why.
- If you discover the plan is wrong, stop, update the plan file, and tell me what changed.

**Phase 5 — Verify**
- Run every command in <definition_of_done>. Fix every failure. Do not report "done"
  with anything red, skipped or `.only`.

**Phase 6 — Self-review**
- Run the `test-reviewer` and `docs-reviewer` subagents on your diff, and use Playwright MCP to walk every screen.
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
- `pnpm --filter @agentkeel/dashboard build`
- `pnpm size`
</definition_of_done>

<deliverable>
- README screenshots/GIF of activity + approval (via Playwright)
- Docs: "Dashboard" page
- Final report in this shape:
  ```
  ## P13 report
  Summary: <3 lines>
  Acceptance criteria: <each criterion → test name → ✅/❌>
  Commands run: <command → result>
  Benchmarks (if any): <name → p50/p95 → budget>
  Deviations from the plan and why:
  Review findings fixed / deferred:
  Follow-up issues to open (title + one line each):
  Tools used:
  Suggested PR title: feat(dashboard): add local dashboard (home, activity, trace, approvals, policies, settings)
  ```
</deliverable>

<user_notes>
$ARGUMENTS
</user_notes>
