# AgentKeel — guide for Claude Code

AgentKeel is the open-source stability layer for AI agents: every tool call an agent
makes goes through AgentKeel, which decides **allow / ask a human / block**, records
the full story in a hash-chained event log, and turns mistakes into tests.
Loop: Protect → Observe → Learn → Test → Shadow → Build. Licence: Apache-2.0.

People will put this in front of agents that delete data and move money.
**Safety and correctness beat speed and cleverness, always.**

## Source of truth (read before designing anything)

| Need | File |
|---|---|
| What to build, acceptance criteria | `docs/design/PRD.md` (features F-01…F-22, NFR-01…18) |
| How it is built: architecture, LLD, API, DB, ADRs | `docs/design/TDD.md` |
| Event format | `docs/design/EVENT-SCHEMA.md` |
| Process: tests, CI, commits, releases | `docs/design/SDLC.md` |
| Libraries and why | `docs/design/TECH-STACK.md` |
| One-page diagrams (read the PNG) | `docs/design/flows/*.png` |
| Decisions | `adr/` |

If code and these documents disagree, **stop and ask**. Do not silently pick one.

## Repository map

```
packages/spec          JSON Schemas, Zod schemas, generated types, error catalogue   (L1)
packages/policy        parse → validate → resolve packs → compile → evaluate; PURE   (L1)
packages/core          decision pipeline, redaction, state machines, ports; PURE      (L1)
packages/sdk           guard(), buffer, spool, Hub client, control snapshot           (L2)
packages/hub           Keel Hub: Hono API v1, ingest, workers, SSE, serves dashboard   (L2)
packages/store-sqlite  Store port on SQLite (WAL, STRICT)                             (L2)
packages/mcp-proxy     MCP stdio proxy                                                (L2)
packages/notifiers/*   slack (Bolt, Socket Mode), telegram (grammY)                   (L2)
packages/adapters/*    claude-code hooks, later framework adapters                    (L3)
packages/cli           `agentkeel` binary: init, demo, doctor, hub, ui, kill, …       (L3)
packages/dashboard     Vite + React SPA (talks only to API v1)                        (L3)
packs/                 official policy packs (YAML + tests + docs)
examples/              runnable protected agents (tested in CI)
docs/                  Starlight site; docs/design = design documents
```

Layering is enforced by dependency-cruiser: `spec` ← `policy` ← `core` ← adapters/stores ←
`sdk`/`hub`/`mcp-proxy` ← `cli`. **`policy` and `core` never import I/O** (no fs, net,
timers, process, Date.now — use the `Clock` port).

## Commands

```bash
pnpm install                 # once
pnpm build                   # all packages (turbo, cached)
pnpm test                    # vitest, all packages;  pnpm --filter @agentkeel/policy test
pnpm test:watch
pnpm lint                    # biome check + dependency-cruiser
pnpm typecheck               # tsc --build
pnpm bench                   # micro-benchmarks;  pnpm bench:compare  (vs main)
pnpm size                    # size-limit budgets
pnpm conformance             # shared decision vectors
pnpm --filter docs dev       # docs site
```

Before saying a task is done, run: `pnpm lint && pnpm typecheck && pnpm test` (plus
`pnpm bench` for L1 changes). Paste the summary of the results.

## Non-negotiable rules

1. **Fail safe.** Every error on the decision path ends in `on_error` (default **block**)
   and an `engine.error` event. Never let an exception reach the agent, never fail open.
2. **A blocked tool function is never invoked.** Tests must prove it.
3. **Redact before storing or sending** anything derived from tool args/results.
   Never log raw args, results, tokens or secrets.
4. **Most-restrictive-wins** (block > ask > allow > default). Rule order never matters.
5. **Hot path is sacred:** no disk, network or locks when deciding an `allow`,
   unless a limit or approval explicitly needs the Hub.
6. **Wire format is snake_case**, ids are TypeIDs (`evt_`, `act_`, `apr_`, …), times RFC 3339 UTC.
7. **Public API, policy language and event schema changes need an ADR** — ask first.
8. **No new runtime dependency** without stating why in the plan (size, licence, maintenance).
9. **Never edit a test just to make it pass.** If a test is wrong, say so and explain.
10. **No hard-coding to tests.** Implement the general behaviour the spec describes.

## Code style

- TypeScript strict (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`). No `any`;
  use `unknown` and narrow. Explicit return types on exported functions.
- Small pure functions; comments explain *why*, not *what*. TSDoc on every export.
- Errors: classes extending `AgentKeelError` with stable codes from `packages/spec/errors`:
  `AK-1xxx` policy · `AK-2xxx` approvals/API · `AK-3xxx` SDK · `AK-4xxx` store ·
  `AK-5xxx` CLI · `AK-6xxx` MCP. Message = what happened. Why. How to fix. Docs link.
- Validation at boundaries with Zod; inside the core, trust types.
- Tests next to code (`*.test.ts`); property tests `*.prop.test.ts`; benchmarks `*.bench.ts`.
- Use `fast-check` for invariants, never `Math.random` in tests (seeded only).

## Git and PRs

- Branch per task: `feat/<scope>-<short>`; commits signed off: `git commit -s`.
- Conventional Commits; scopes: policy, core, spec, sdk, hub, cli, dashboard, mcp,
  notifiers, python, packs, docs, ci.
- Small focused commits (tests first, then implementation, then docs).
- **Do not push, open PRs, merge or publish unless explicitly asked.**

## Working style

- Start in plan mode for anything non-trivial; write the plan and wait for approval.
- Use subagents (Explore) for wide searches to keep context small; use the reviewer
  agents in `.claude/agents/` before handing work back.
- Check current library APIs with Context7 MCP (if installed) or the installed source
  in `node_modules` — do not rely on memory for library APIs.
- When unsure about a requirement, ask one precise question instead of guessing.
