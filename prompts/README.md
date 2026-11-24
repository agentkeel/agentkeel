# AgentKeel prompt pack for Claude Code

24 production-grade prompts plus `CLAUDE.md`, 5 reviewer subagents and project MCP
config. Every prompt gives Claude Code an expert **role**, the exact design documents to read,
scope, requirements, required tests, acceptance criteria, the **tools/plugins** to use, an
8-phase workflow with a mandatory plan-approval stop, a quality bar and a report format.

## What is where

| Path | What |
|---|---|
| `CLAUDE.md` | Project memory Claude Code loads every session (rules, commands, layout) |
| `.claude/commands/ak-*.md` | The 24 prompts, usable as slash commands |
| `.claude/agents/*.md` | Reviewer roles: security, performance, test, architecture, docs |
| `.claude/settings.json` | Safe permissions (no `.env` reads, no force push, no publish) |
| `.mcp.json` | Project MCP servers: Context7 (live library docs), Playwright (browser) |
| `docs/design/*.md` | PRD, SDLC, TDD, Event Schema, Tech Stack as Markdown (+ `flows/` diagrams) |

## How to run a prompt

```bash
claude                                   # in the repo root
/ak-p05-policy-engine                     # run a prompt
/ak-p05-policy-engine keep CEL out, focus on glob performance   # with extra notes
```

Or open the `.md` file and paste its body (without the `---` header) into Claude Code.

**Every build prompt stops after the plan.** Read `.claude/plans/Pxx.md`, then reply
`approved` or give changes. Never skip this step for L1 packages.

## Build order (matches the Build Plan)

| Week | Prompt | Feature |
|---|---|---|
| 1 | `/ak-p01-monorepo-setup` | Monorepo skeleton |
| 2 | `/ak-p02-spec-package` | Schemas, types, errors |
| 3 | `/ak-p03-test-harness`, `/ak-p04-docs-site` | Bench, conformance, docs site |
| 4–5 | `/ak-p05-policy-engine` | F-03 |
| 6 | `/ak-p06-sdk-guard` | F-01 |
| 7 | `/ak-p07-event-store-hub` | F-07 |
| 8 | `/ak-p08-cli-init` | F-17 |
| 9 | `/ak-p09-mcp-proxy` | F-02 |
| 10 | `/ak-p10-approvals` | F-04 |
| 11 | `/ak-p11-kill-limits`, `/ak-p12-audit-verify` | F-05, F-08 |
| 12 | `/ak-p13-dashboard` | F-09 |
| 13 | `/ak-p14-policy-packs`, `/ak-p15-claude-code-hooks` | F-06, F-18 |
| 14 | `/ak-p16-docs-examples`, `/ak-m3-release-prep 0.1.0-rc.1` | F-22, RC |

Use **R1–R3** before every PR of an L1/L2 feature, **M1–M5** whenever needed.

## One-time tool setup

1. **MCP servers:** the first time you start `claude` in the repo it asks to approve the
   servers in `.mcp.json` (Context7, Playwright). Approve both.
2. **Plugins** (optional but recommended): run `/plugin`, open the official Anthropic
   marketplace and install what is available among: `feature-dev`, `code-review`,
   `pr-review-toolkit`, `security-guidance`, `frontend-design`, `commit-commands`.
   Names can change; every prompt works without them.
3. **GitHub:** `gh auth login` so prompts can read issues and PRs.
4. Add to `.gitignore`: `.claude/plans/` and `.claude/settings.local.json`.

## Getting the most from a $20 plan

- **One prompt = one session.** Run `/clear` before starting a new prompt.
- Use `/compact` when a session gets long; the plan file keeps the important context.
- Use the default model for implementation; switch to the strongest model your plan allows
  only for L1 planning and security reviews.
- Let subagents do wide searches (they keep the main context small).
- If you hit a usage limit, stop at a phase boundary; the plan file and commits let you
  resume with: `Continue Pxx from Phase N. Read .claude/plans/Pxx.md first.`

## Prompt engineering practices used

- Role, mission and context first; clear sections in XML tags.
- Explicit scope (in and out) so the model does not wander.
- Explore → Plan → STOP → Tests first → Implement → Verify → Review → Docs.
- Verifiable acceptance criteria and exact commands for "done".
- Reasons given for constraints (fail-safe, privacy, performance budgets).
- Independent reviewer subagents with their own roles.
- Instruction to verify library APIs with Context7 instead of memory.
- Fallback rule when a tool or plugin is missing.
