# AgentKeel PRD v1.0

> Markdown copy of the Word document for use by contributors and Claude Code. The Word/PDF version is the formatted original; diagrams are in `flows/`.

# 1. Document Overview

This Product Requirements Document (PRD) turns the AgentKeel Business Requirements Document (BRD v1.0) into a buildable product definition. The BRD answered **why** AgentKeel should exist and **who** it serves. This PRD answers **what exactly** it does: every feature, user story, functional requirement, acceptance criterion and quality target, release by release, with traceability back to the 30 business requirements (BR-01 to BR-30).

It is written so that a contributor who has never spoken to the maintainer can pick any feature, read its section and know what "done" means. It is also the source for the next documents: the SDLC Strategy, the Technical Design Document (TDD) and the Event Schema Specification.

## 1.1 Scope of this PRD

| In scope | Out of scope (covered elsewhere) |
| --- | --- |
| All features of the six loop stages: Protect, Observe, Learn, Test, Shadow, Build | Architecture, database tables, APIs and code structure (TDD) |
| Policy language, CLI commands, dashboard screens, event types (product level) | Full field-by-field event format (Event Schema Spec) |
| Non-functional requirements and developer experience targets | CI/CD, bots, branching and release automation (SDLC Strategy) |
| Release scope v0.1, v0.2, v0.3, v1.0 and release criteria | Business case, market, sustainability (BRD) |
| Telemetry and privacy behaviour inside the product | Paid AgentKeel Cloud product (future, separate PRD) |

## 1.2 Audience

| Reader | What they use this PRD for |
| --- | --- |
| Maintainer (Ashutosh Kumar Rao) | Decide scope per release, say no to features that do not fit, plan build cycles. |
| Contributors | Understand a feature before opening a pull request; check acceptance criteria. |
| Design partners and early users | See what is coming and give feedback before it is built. |
| Claude Code (AI pair programmer) | Feature sections are written so they can be pasted into build prompts as the specification. |
| QueueOS team | Know which AgentKeel capabilities QueueOS can rely on and when. |

## 1.3 Conventions

| Convention | Meaning |
| --- | --- |
| F-xx | Feature ID. Each feature belongs to one loop stage. |
| FR-xx.y | Functional requirement y of feature xx. Testable statement. |
| NFR-xx | Non-functional requirement (performance, security, privacy, reliability, compatibility). |
| BR-xx | Business requirement from the BRD. Every feature traces to at least one BR. |
| Must / Should / Could | MoSCoW priority. A release cannot ship with an open Must for that release. |
| v0.1 to v1.0 | Target release. v0.1 = first public release (March 2027). |
| "Agent" | Any software where an LLM decides which tool to call: coding agents, support agents, workflow agents. |
| "Action" | One attempt by an agent to call a tool: run a command, send an email, call an API, write a file. |

## 1.4 Related documents

- **AgentKeel BRD v1.0:** problem, market, personas, open-source strategy, business requirements BR-01 to BR-30.
- **AgentKeel SDLC Strategy (next):** how the project is built, reviewed, tested and released as production-grade open source.
- **AgentKeel TDD and Event Schema Spec (after SDLC):** HLD, LLD, storage, APIs and the open event format.
- **QueueOS BRD, PRD and TDD:** the paid product that will be the first production user of AgentKeel.

# 2. Product Summary

**AgentKeel is the open-source stability layer for AI agents.** It sits between an agent and the tools it calls. Every action passes through AgentKeel, which decides (allow, ask a human, block), records the full story, turns mistakes into test cases, replays them against new versions, lets new versions run in shadow on real traffic, and does all of this with one install, one YAML file, one CLI and one dashboard.

1. **Protect** – Policies, approvals, kill switch
2. **Observe** – Trace and audit every action
3. **Learn** – Mistakes become cases
4. **Test** – Replay and red-team in CI
5. **Shadow** – Try on live traffic, act on nothing
6. **Build** – One config, CLI, dashboard

## 2.1 Product goals

| Goal | How the product shows it | Measure |
| --- | --- | --- |
| G1  Safe by default | Dangerous actions are blocked or need approval before the developer writes a single rule, using policy packs. | Share of new projects that keep a policy pack on after 7 days |
| G2  Five-minute value | `npx agentkeel init` to first protected and traced action in under five minutes. | Median time to first protected action (opt-in telemetry and user tests) |
| G3  Full story of every action | One trace shows input, decision, policy result, approver, tool result and cost. | Percentage of actions with complete traces |
| G4  Never the same mistake twice | Blocked and rejected actions become test cases that run in CI. | Cases captured per active project; CI runs per week |
| G5  Invisible in the hot path | Policy check adds only a few milliseconds and never crashes the agent. | p95 overhead per action |
| G6  Neutral and open | Works with any model, framework and cloud; data stays local by default. | Number of adapters; zero mandatory network calls |

## 2.2 Non-goals

Saying no is part of the product. AgentKeel will **not**:

- **Build agents.** It is not an agent framework or orchestrator; it protects agents built with any framework.
- **Be a model gateway or router.** It does not proxy LLM calls for cost routing; it governs tool calls (actions).
- **Be a full LLM observability platform.** It records actions and decisions deeply; for token-level prompt analytics it exports to Langfuse or OpenTelemetry.
- **Filter all model text.** Content moderation of every model output is not the goal; risky **actions** are.
- **Require a cloud account.** Everything in the core loop works offline on one machine.
- **Guarantee perfect safety.** It reduces risk with layered controls; documentation is honest about limits.

## 2.3 Product principles

| Principle | What it means for decisions |
| --- | --- |
| Fail safe, not fail silent | If AgentKeel cannot decide (crash, timeout), the default is the policy's `on_error` (block by default for risky tools) and the event is recorded. |
| Configuration over code | Most users should never write code to use AgentKeel beyond one wrapper line; rules live in `agentkeel.yaml`. |
| One data model | Every feature reads and writes the same event format. No feature gets its own private log. |
| Local first | Default storage is a local file; no telemetry unless the user says yes. |
| Explain every decision | Every block or ask shows which rule matched and why, in the CLI, dashboard and event. |
| Small core, open edges | The core stays small; detectors, adapters, notifiers and policy packs are plugins. |

# 3. Users, Jobs and Key Journeys

Personas are defined in detail in the BRD (Section 7). This PRD uses them to decide priorities. The table below lists the main job each persona hires AgentKeel for and the features that serve it.

| Persona | Job to be done | First features they touch |
| --- | --- | --- |
| Riya, indie developer building with Claude Code and MCP | "Stop my coding agent from deleting things or pushing to main, without slowing me down." | F-17 init, F-06 policy packs, F-02 MCP proxy, F-04 approvals on Telegram |
| Aditya, AI engineer at a startup shipping a support agent | "Let the agent issue refunds, but big ones need a human, and show me what it did." | F-01 SDK, F-03 policies, F-04 Slack approvals, F-09 dashboard, F-12 replay |
| Farah, security engineer reviewing agent rollouts | "Prove what agents did, who approved it, and that logs were not changed." | F-08 audit log, F-07 events, F-10 exporters, F-15 policy simulation |
| Tanmay, first-time open-source contributor | "Add something useful in a weekend and get it merged." | F-20 plugins, F-06 policy packs, F-22 docs and examples |

## 3.1 Journey A: first five minutes (Riya)

1. **Install** – `npx agentkeel init`
2. **Choose** – Picks "coding agent" pack
3. **Connect** – Hooks Claude Code / MCP
4. **Act** – Agent tries `rm -rf`
5. **Blocked** – Clear reason shown
6. **See** – `agentkeel ui` trace

Success: Riya sees a real blocked action with its reason in under five minutes, without reading docs beyond the README.

## 3.2 Journey B: approval in production (Aditya)

1. **Request** – Agent calls `refund(1200)`
2. **Match** – Rule: amount > 500 → ask
3. **Notify** – Slack message with context
4. **Decide** – Lead taps Approve / Reject
5. **Resume** – Agent continues or stops
6. **Record** – Trace with approver

Success: the approver decides from Slack alone, without opening any other tool, and the agent resumes within two seconds of the click.

## 3.3 Journey C: from mistake to regression test (Aditya, v0.2)

1. **Reject** – Human rejects action
2. **Capture** – Case saved with context
3. **Label** – Expected: block
4. **Change** – New prompt / model
5. **Replay** – `agentkeel test` in CI
6. **Gate** – PR fails if repeated

## 3.4 Journey D: safe rollout with shadow (v0.3)

1. **Deploy** – v2 next to v1
2. **Mirror** – v2 sees same inputs
3. **Record** – v2 actions not executed
4. **Compare** – Diff v1 vs v2
5. **Decide** – Promote or fix

# 4. Product Structure

AgentKeel is one product made of a small number of parts that users see. The TDD will define how they are built; this section defines what each part is responsible for from a user's point of view.

| Part | What the user sees | Stage | First release |
| --- | --- | --- | --- |
| SDKs (`@agentkeel/sdk`, `agentkeel` for Python) | A `guard()` wrapper around tools, or a one-line hook for supported frameworks. | Protect, Observe | TS v0.1, Python v0.2 |
| MCP proxy | Put AgentKeel between any MCP client and server by changing one line of MCP config. | Protect, Observe | v0.1 |
| Policy engine | Reads `agentkeel.yaml`, returns allow / ask / block with the matching rule. | Protect | v0.1 |
| Approval service | Sends approval requests to Slack, Telegram, CLI or dashboard and waits for a decision. | Protect | v0.1 |
| Event store | Local file database of all events, with a hash chain for tamper evidence. | Observe | v0.1 |
| CLI (`agentkeel`) | init, check, ui, tail, approve, kill, test, replay, shadow, export. | Build | v0.1 |
| Local dashboard | Browser UI at `localhost` for traces, approvals, policies, cases, test runs. | Observe, Build | v0.1 |
| Case library | Saved cases from blocked, rejected and flagged actions. | Learn | v0.2 |
| Test runner and GitHub Action | Replay cases and red-team suites; pass or fail in CI. | Test | v0.2 |
| Shadow runner | Run a candidate version in record-only mode and compare with live. | Shadow | v0.3 |
| Server mode | Self-hosted shared dashboard and store for a team. | Build | v1.0 |
| Plugin interface | Add detectors, notifiers, adapters, exporters and policy packs. | Build | v1.0 (stable), v0.2 (preview) |

## 4.1 How an action flows

*Figure 4.1  Action flow through AgentKeel*

```text
agent decides to call tool  ──►  AgentKeel SDK / hook / MCP proxy
                                     │  builds ActionRequest (tool, args, agent, session)
                                     ▼
                               Policy engine  ──► rule match: allow | ask | block (+ reason)
                                     │
             ┌───────────────────────┼─────────────────────────┐
           allow                    ask                       block
             │                       ▼                          │
             │              Approval service ── Slack/Telegram/CLI/UI
             │                 approved │ rejected / timeout     │
             ▼                          ▼                        ▼
       tool executes            execute or deny          agent gets structured denial
             └──────────────► Event store (hash-chained) ◄───────┘
                                     │
                    dashboard · cases · replay · shadow · exporters
```

Every branch ends in the event store. This single rule is what makes the loop possible: Learn, Test and Shadow all work from the same recorded events.

# 5. Release Scope

AgentKeel ships in four public releases. Each release completes more of the loop and is useful on its own. A feature listed for a later release may appear early as a preview behind an `experimental` flag, but it is not promised until its release.

| Release | Window | Theme | Loop stages complete | Headline features |
| --- | --- | --- | --- | --- |
| v0.1 | Build Dec 2026 to Feb 2027; launch early Mar 2027 | Protect and see | Protect, Observe, Build (basic) | TS SDK, MCP proxy, policies, approvals (Slack, Telegram, CLI, UI), kill switch, budgets, event store, audit chain, local dashboard, policy packs, `init` |
| v0.2 | Mar to Apr 2027 | Learn and test | + Learn, Test | Case capture, case library, replay, red-team suite, GitHub Action, Python SDK, first framework adapters, signed releases |
| v0.3 | May to Jul 2027 | Roll out safely | + Shadow | Shadow mode and compare, policy simulation, OpenTelemetry and Langfuse export, more adapters |
| v1.0 | Q4 2027 | Stable for teams | Full loop, stable | Stable API and Event Schema 1.0, self-hosted server mode, plugin interface 1.0, deprecation policy |

## 5.1 Feature to release matrix

| Feature | Stage | v0.1 | v0.2 | v0.3 | v1.0 |
| --- | --- | --- | --- | --- | --- |
| F-01 TypeScript SDK and `guard()` | Protect | Must |  |  | Stable |
| F-02 MCP proxy | Protect | Must |  | HTTP transport | Stable |
| F-03 Policy engine and `agentkeel.yaml` | Protect | Must | Conditions+ |  | Stable |
| F-04 Human approvals | Protect | Must | Email |  | Stable |
| F-05 Kill switch, budgets, rate limits | Protect | Must |  |  | Stable |
| F-06 Policy packs | Protect | Should | More packs |  | Stable |
| F-07 Event recorder | Observe | Must |  |  | Schema 1.0 |
| F-08 Tamper-evident audit log | Observe | Should |  |  | Stable |
| F-09 Local dashboard | Observe | Must | Cases, tests | Shadow | Server |
| F-10 Exporters (OTel, Langfuse, JSONL) | Observe | JSONL |  | Must | Stable |
| F-11 Case capture and library | Learn |  | Must |  | Stable |
| F-12 Replay | Test |  | Must |  | Stable |
| F-13 Red-team suite | Test |  | Should | More attacks | Stable |
| F-14 CI and GitHub Action | Test |  | Must |  | Stable |
| F-15 Policy simulation | Test |  |  | Should | Stable |
| F-16 Shadow mode and compare | Shadow |  |  | Must | Stable |
| F-17 CLI and `init` | Build | Must |  |  | Stable |
| F-18 Framework adapters | Build | Claude Code | OpenAI Agents, LangGraph | CrewAI, Vercel AI | + community |
| F-19 Python SDK | Build |  | Must |  | Stable |
| F-20 Plugin interface | Build |  | Preview |  | Must |
| F-21 Self-hosted server mode | Build |  |  |  | Should |
| F-22 Docs site and examples | Build | Must | Grows | Grows | Complete |

> **Decisions taken in this PRD (closing BRD open questions)**
>
> - **BRD Q2, first integrations:** v0.1 ships the generic TypeScript `guard()` wrapper, the MCP proxy (covers every MCP client) and Claude Code hooks. v0.2 adds OpenAI Agents SDK and LangGraph adapters together with the Python SDK.
> - **BRD Q3, telemetry:** `agentkeel init` asks once, the default answer is **No**, and the choice is written to the config file. CI and non-interactive runs never ask and never send. Section 13 has the details.

# 6. Feature Requirements: Protect

Protect is the entry point of the loop and the reason most users install AgentKeel. It must work from the first minute, explain every decision, and never become the reason an agent crashes.

### F-01  TypeScript SDK and guard()

| Attribute | Value |
| --- | --- |
| Description | A small library that wraps any tool function so every call goes through the policy engine and is recorded. Works with plain functions and with tool objects from popular TypeScript agent libraries. |
| Traces to | BR-01, BR-06, BR-23 |
| Release | v0.1 (Must) |

**User stories**

- As a developer, I want to wrap my existing tools with one function so that I do not rewrite my agent.
- As a developer, I want a blocked action to return a clear, structured result to the agent so that the agent can explain it or try a safer path instead of crashing.
- As a developer, I want to tag actions with agent name, version and session so that traces are easy to filter.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-01.1 | `guard(tool, options)` returns a function with the same signature that runs the policy check before calling the tool. | Must | v0.1 |
| FR-01.2 | `guardAll({ ...tools })` wraps a whole tool map in one call. | Must | v0.1 |
| FR-01.3 | On block or reject, the SDK returns (or throws, configurable) an `AgentKeelDenied` result with rule id, reason and suggestion. | Must | v0.1 |
| FR-01.4 | Context (agent, version, session, user, custom tags) can be set globally or per call. | Must | v0.1 |
| FR-01.5 | The SDK records `action.requested`, `policy.decided`, `action.executed` / `action.denied` and `action.result` events. | Must | v0.1 |
| FR-01.6 | Arguments and results are redacted by configurable patterns (keys, tokens, emails, phone numbers) before storage. | Must | v0.1 |
| FR-01.7 | Works in Node 22+ (current LTS lines) and Bun; ships ESM and CJS with full types. | Should | v0.1 |

**Acceptance criteria**

- Wrapping a tool with `guard()` needs at most two added lines of code in the quick-start example.
- With an allow-all policy, the wrapped tool returns exactly what the original tool returns.
- A blocked call never executes the tool; a unit test proves the tool function was not invoked.
- If the policy engine throws, the configured `on_error` behaviour applies and an `engine.error` event is recorded.

### F-02  MCP proxy

| Attribute | Value |
| --- | --- |
| Description | A local proxy that sits between an MCP client (Claude Code, Claude Desktop, Cursor and others) and one or more MCP servers. Every `tools/call` request is checked by policy and recorded. Users change one line in their MCP config and nothing else. |
| Traces to | BR-02, BR-06 |
| Release | v0.1 stdio (Must); v0.3 Streamable HTTP (Should) |

**User stories**

- As a Claude Code user, I want to protect every MCP server I use without changing the servers.
- As a security engineer, I want to see a list of all MCP tools each agent can reach.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-02.1 | `agentkeel mcp wrap -- <server command>` starts the real server as a child process and proxies stdio. | Must | v0.1 |
| FR-02.2 | `tools/call` requests are evaluated by the policy engine; denied calls return a valid MCP error result with the reason. | Must | v0.1 |
| FR-02.3 | `tools/list` is passed through and recorded as an inventory event; tools can be hidden by policy. | Should | v0.1 |
| FR-02.4 | `agentkeel mcp install` rewrites an existing MCP config file to route servers through the proxy, with a backup. | Should | v0.1 |
| FR-02.5 | Approval (`ask`) holds the MCP call open until decided or timed out. | Must | v0.1 |
| FR-02.6 | Streamable HTTP transport for remote MCP servers. | Should | v0.3 |

**Acceptance criteria**

- Claude Code with the proxy behaves identically to without it under an allow-all policy (manual and automated test).
- Proxy adds under 10 ms p95 per `tools/call` on a typical laptop, excluding approval wait time.
- If the real server exits, the proxy exits with the same code and logs the reason.

### F-03  Policy engine and agentkeel.yaml

| Attribute | Value |
| --- | --- |
| Description | The decision maker. Reads one declarative YAML file and returns allow, ask or block for each action, with the matching rule and a human-readable reason. Full language in Section 12. |
| Traces to | BR-03, BR-23 |
| Release | v0.1 (Must); richer conditions in v0.2 |

**User stories**

- As a developer, I want to write rules like "refund above 500 needs approval" without code.
- As a security engineer, I want to set a safe default so that unknown tools are not silently allowed.
- As a developer, I want to check my policy file for mistakes before running my agent.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-03.1 | Rules match on tool name (exact, glob), arguments (operators), agent, environment and time. | Must | v0.1 |
| FR-03.2 | Effects: `allow`, `ask`, `block`; optional `reason`, `notify`, `timeout`, `on_timeout`. | Must | v0.1 |
| FR-03.3 | Evaluation: block rules win over ask, ask wins over allow; then the `default` effect applies. | Must | v0.1 |
| FR-03.4 | `agentkeel check` validates the file against a JSON Schema and reports line-level errors. | Must | v0.1 |
| FR-03.5 | Hot reload: policy file changes apply without restarting the agent. | Should | v0.1 |
| FR-03.6 | `agentkeel explain <event-id>` shows which rules were considered and why one matched. | Should | v0.1 |
| FR-03.7 | Custom conditions via a small expression language (CEL subset) and plugin detectors. | Should | v0.2 |

**Acceptance criteria**

- Policy evaluation p95 under 2 ms for a file with 200 rules (benchmark in CI).
- A malformed policy never loads silently; the last valid policy stays active and an error is shown.
- Every decision event stores the policy file hash and rule id that produced it.

### F-04  Human approvals

| Attribute | Value |
| --- | --- |
| Description | When a rule says `ask`, AgentKeel pauses the action and asks a human where they already are: Slack, Telegram, the terminal or the dashboard. The approver sees enough context to decide in seconds. |
| Traces to | BR-04 |
| Release | v0.1 (Slack, Telegram, CLI, dashboard); v0.2 email and webhook |

**User stories**

- As a team lead, I want to approve a risky action from my phone in one tap.
- As a developer, I want to choose what happens if nobody answers in time.
- As an auditor, I want to know who approved what and when.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-04.1 | Approval message shows agent, tool, key arguments (redacted), matched rule, reason and a link to the trace. | Must | v0.1 |
| FR-04.2 | Slack: interactive message with Approve / Reject buttons and optional comment (Slack app with Socket Mode, no public URL needed). | Must | v0.1 |
| FR-04.3 | Telegram: bot message with inline buttons; approvers restricted to configured user IDs. | Must | v0.1 |
| FR-04.4 | CLI (`agentkeel approve`) and dashboard approvals inbox. | Must | v0.1 |
| FR-04.5 | Timeout with `on_timeout: block \| allow` (default block). | Must | v0.1 |
| FR-04.6 | Only listed approvers can decide; an approver cannot approve their own agent if `separate_approver: true`. | Should | v0.1 |
| FR-04.7 | Email and generic webhook notifiers. | Should | v0.2 |

**Acceptance criteria**

- From button click to agent resuming takes under 2 seconds on a normal connection.
- A decision from a non-listed user is refused and recorded as `approval.refused`.
- Every approval event records approver identity, channel, decision, comment and timestamps.

### F-05  Kill switch, budgets and rate limits

| Attribute | Value |
| --- | --- |
| Description | Hard stops that do not depend on individual rules: stop every action immediately, cap spending, and limit how often a tool can be called. |
| Traces to | BR-05 |
| Release | v0.1 (Must) |

**User stories**

- As an operator, I want one command to stop all agents when something looks wrong.
- As a developer, I want to cap how much money an agent can move or spend per day.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-05.1 | `agentkeel kill` (and a dashboard button, and a Slack/Telegram command) blocks all actions until `agentkeel resume`. | Must | v0.1 |
| FR-05.2 | Kill can be scoped: all agents, one agent, one tool. | Should | v0.1 |
| FR-05.3 | Budgets: sum of a numeric argument (e.g., amount) per agent per window; over-budget actions get the configured effect. | Must | v0.1 |
| FR-05.4 | Rate limits: max calls per tool per window; loop detection for repeated identical calls. | Must | v0.1 |

**Acceptance criteria**

- After `kill`, the next action of any guarded agent is blocked within 1 second.
- Kill state survives process restart until explicitly resumed.
- A test agent stuck in a loop of identical calls is stopped by the default loop rule.

### F-06  Policy packs

| Attribute | Value |
| --- | --- |
| Description | Ready, reviewed sets of rules for common agent types, so users are safe before writing any rule. Packs are versioned and can be extended or overridden. |
| Traces to | BR-09 |
| Release | v0.1 (Should); more packs each release |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-06.1 | v0.1 packs: `coding-agent` (shell, git, file system), `mcp-baseline`, `email`, `payments`. | Should | v0.1 |
| FR-06.2 | `extends: [agentkeel/coding-agent@1]` in the policy file; local rules override pack rules. | Must | v0.1 |
| FR-06.3 | Each pack has documentation, examples and its own test cases that run in CI. | Must | v0.1 |
| FR-06.4 | Community packs can be published as npm or PyPI packages with a naming convention. | Could | v0.2 |

**Acceptance criteria**

- The `coding-agent` pack blocks `rm -rf /`, force push to protected branches and reading `.env` files in tests.
- Upgrading a pack major version never happens silently; the version is pinned in the policy file.

# 7. Feature Requirements: Observe

Observe gives every action a full, trustworthy story. It is also the foundation for the rest of the loop: if an event is not recorded correctly, it cannot be learned from, tested or compared.

### F-07  Event recorder

| Attribute | Value |
| --- | --- |
| Description | Records every action, decision, approval and result as events in one open format (AgentKeel Event Schema), grouped into traces and sessions. Stored locally in a single file database by default. |
| Traces to | BR-06, BR-22, BR-24 |
| Release | v0.1 (Must); schema 1.0 stable at v1.0 |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-07.1 | Every event has id, type, timestamp, trace id, session id, agent, version, schema version and payload. | Must | v0.1 |
| FR-07.2 | Events are written asynchronously; recording failure never blocks the action (it is reported). | Must | v0.1 |
| FR-07.3 | Default store is a local SQLite file under `.agentkeel/`; retention configurable (default 30 days). | Must | v0.1 |
| FR-07.4 | Cost and latency fields on action events when provided by the caller. | Should | v0.1 |
| FR-07.5 | Schema version included in every event; older events stay readable after upgrades. | Must | v0.1 |

**Acceptance criteria**

- A 10,000-action test run records 100% of events with no gaps in trace ids.
- Killing the process mid-run loses at most the last 1 second of buffered events.

### F-08  Tamper-evident audit log

| Attribute | Value |
| --- | --- |
| Description | Each event stores the hash of the previous event, forming a chain. Changing or deleting any past event breaks the chain, and `agentkeel verify` shows exactly where. |
| Traces to | BR-07 |
| Release | v0.1 (Should) |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-08.1 | SHA-256 hash chain per store; each event includes `prev_hash` and `hash`. | Should | v0.1 |
| FR-08.2 | `agentkeel verify` checks the chain and reports the first broken link. | Should | v0.1 |
| FR-08.3 | Signed checkpoint export (hash of chain head) that can be stored elsewhere. | Could | v0.3 |

**Acceptance criteria**

- Editing one byte of any stored event makes `verify` fail and name that event.
- Retention deletes are recorded as a signed `retention.pruned` event so pruning is not mistaken for tampering.

### F-09  Local dashboard

| Attribute | Value |
| --- | --- |
| Description | A browser dashboard started with `agentkeel ui`, bound to localhost. It is the single place to see traces, approve actions, read policies, browse cases and see test and shadow results. Screen list in Section 15. |
| Traces to | BR-08 |
| Release | v0.1 (Must); grows each release |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-09.1 | Live activity feed of actions with decision colour (allowed, asked, blocked). | Must | v0.1 |
| FR-09.2 | Trace view: timeline of every event in one trace with redacted arguments. | Must | v0.1 |
| FR-09.3 | Approvals inbox with approve and reject. | Must | v0.1 |
| FR-09.4 | Policy viewer showing active rules, pack versions and hit counts. | Should | v0.1 |
| FR-09.5 | Filters by agent, tool, decision, time; search by id. | Must | v0.1 |
| FR-09.6 | Kill switch button with confirmation. | Must | v0.1 |

**Acceptance criteria**

- Dashboard binds to 127.0.0.1 only by default and needs a one-time local token.
- Feed shows a new action within 1 second; trace view loads in under 500 ms for 1,000 events.
- Meets WCAG 2.1 AA colour contrast; decision state is never shown by colour alone.

### F-10  Exporters

| Attribute | Value |
| --- | --- |
| Description | Send AgentKeel events to tools teams already use, so AgentKeel adds to their stack instead of replacing it. |
| Traces to | BR-18 |
| Release | JSONL v0.1; OpenTelemetry and Langfuse v0.3 |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-10.1 | `agentkeel export --format jsonl` for any time range. | Must | v0.1 |
| FR-10.2 | OpenTelemetry exporter (OTLP) mapping traces and spans with GenAI semantic conventions where they exist. | Must | v0.3 |
| FR-10.3 | Langfuse exporter. | Should | v0.3 |

**Acceptance criteria**

- Exported JSONL validates against the published Event Schema.
- An exporter failure never blocks actions; events are retried with backoff.

# 8. Feature Requirements: Learn

Learn is what makes AgentKeel more than a firewall. Every time a human or a policy says "no", that moment is valuable knowledge. Learn turns it into a reusable case so the same mistake can be caught before the next release.

### F-11  Case capture and case library

| Attribute | Value |
| --- | --- |
| Description | Blocked actions, rejected approvals and actions a user flags as wrong are saved as cases: the full context (inputs, conversation summary, tool, arguments, decision) plus the expected outcome. Cases live in a folder of plain files so they can be reviewed in Git. |
| Traces to | BR-11 |
| Release | v0.2 (Must) |

**User stories**

- As a developer, I want every rejected action saved automatically so that I can test against it later.
- As a developer, I want to flag a wrongly allowed action from the dashboard so that it becomes a case too.
- As a team, we want cases stored as files in our repository so that they are reviewed like code.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-11.1 | Auto-capture on `action.denied` (policy block) and `approval.rejected`; configurable per rule. | Must | v0.2 |
| FR-11.2 | "Flag as wrong" on any allowed action in the dashboard and CLI (`agentkeel flag <event-id>`). | Must | v0.2 |
| FR-11.3 | Each case stores expected outcome (`block`, `ask`, `allow`, or "tool not called"), source event, tags and a short note. | Must | v0.2 |
| FR-11.4 | Cases are saved as YAML files in `agentkeel/cases/` with redacted data; secrets never written. | Must | v0.2 |
| FR-11.5 | Duplicate detection: near-identical cases are merged with a counter. | Should | v0.2 |
| FR-11.6 | Case library screen: search, tag, edit expected outcome, archive. | Must | v0.2 |

**Acceptance criteria**

- Rejecting an approval creates a case file within 2 seconds containing the trace id and expected outcome.
- A secret-scanning test over generated case files finds zero secrets from the redaction test corpus.
- Cases created on one machine replay on another machine with no edits.

# 9. Feature Requirements: Test

Test answers one question before every release: "Will the new version of my agent repeat a known mistake, or fall for a known attack?" It works locally and in CI.

### F-12  Replay

| Attribute | Value |
| --- | --- |
| Description | Runs saved cases and recorded traces against a new agent version or a new policy, and reports which cases now pass or fail. Two modes: policy-only replay (fast, no model calls) and agent replay (runs the agent with tools mocked from recordings). |
| Traces to | BR-12 |
| Release | v0.2 (Must) |

**User stories**

- As a developer, I want to know in one command whether my new prompt still avoids past mistakes.
- As a developer, I want replays that do not send real emails or move real money.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-12.1 | `agentkeel test` runs all cases; exit code is non-zero if any Must case fails. | Must | v0.2 |
| FR-12.2 | Policy-only mode re-evaluates recorded actions against the current policy without calling any model. | Must | v0.2 |
| FR-12.3 | Agent mode calls a user-provided entry point; tools are replaced by recorded responses (no side effects). | Must | v0.2 |
| FR-12.4 | Results report: pass, fail, flaky (different results across repeated runs), with diff of actions. | Must | v0.2 |
| FR-12.5 | Configurable repeats per case to account for model randomness (default 3, pass if all pass). | Should | v0.2 |
| FR-12.6 | Results stored as test-run events and visible in the dashboard. | Must | v0.2 |

**Acceptance criteria**

- Policy-only replay of 1,000 cases finishes in under 10 seconds on a laptop.
- In agent mode, a test proves no real tool function is invoked.
- Report is available as terminal output, JSON and JUnit XML.

### F-13  Red-team suite

| Attribute | Value |
| --- | --- |
| Description | A built-in set of attack cases (prompt injection in tool results, data exfiltration attempts, privilege escalation, dangerous command tricks) that check whether policies and the agent hold up. Not a replacement for dedicated tools like Promptfoo or garak; a focused suite for agent actions. |
| Traces to | BR-13 |
| Release | v0.2 (Should); grows each release |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-13.1 | At least 50 attack cases at v0.2 across injection, exfiltration, escalation and destructive commands. | Should | v0.2 |
| FR-13.2 | `agentkeel test --suite redteam` runs them alone or with user cases. | Should | v0.2 |
| FR-13.3 | Each attack case maps to an OWASP Top 10 for LLM Applications category where applicable. | Should | v0.2 |
| FR-13.4 | Community can contribute attack cases through the plugin format. | Could | v0.3 |

**Acceptance criteria**

- With the `coding-agent` pack enabled, all destructive-command attack cases are blocked.
- Every attack case has a description, source reference and expected outcome.

### F-14  CI integration and GitHub Action

| Attribute | Value |
| --- | --- |
| Description | Run AgentKeel tests on every pull request and block merges that would repeat known mistakes. |
| Traces to | BR-14 |
| Release | v0.2 (Must) |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-14.1 | Official `agentkeel/test-action` for GitHub Actions with inputs for suites, mode and fail level. | Must | v0.2 |
| FR-14.2 | Posts a summary comment on the pull request (passed, failed, new failures since main). | Should | v0.2 |
| FR-14.3 | Works in any CI through the CLI and JUnit output. | Must | v0.2 |
| FR-14.4 | Never sends telemetry and never prompts in CI. | Must | v0.2 |

**Acceptance criteria**

- A sample repository shows a red pull request when a policy change re-allows a captured case.
- Action runtime overhead (excluding the user's agent) is under 30 seconds.

### F-15  Policy simulation

| Attribute | Value |
| --- | --- |
| Description | Before changing a policy, see what would have happened if the new policy had been active over past traffic. |
| Traces to | BR-19 |
| Release | v0.3 (Should) |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-15.1 | `agentkeel simulate --policy new.yaml --since 7d` re-evaluates recorded actions with the new policy. | Should | v0.3 |
| FR-15.2 | Report shows counts of decisions that would change (allow to block, block to allow, etc.) with examples. | Should | v0.3 |
| FR-15.3 | Dashboard "what if" view for a policy draft. | Could | v0.3 |

**Acceptance criteria**

- Simulation never changes stored events and never calls tools or models.
- Simulation of 100,000 recorded actions completes in under 60 seconds.

# 10. Feature Requirements: Shadow

Shadow lets teams try a new agent version on real traffic with zero risk. It is the last safety step before promotion and the most valuable feature for teams running agents in production, including QueueOS.

### F-16  Shadow mode and compare

| Attribute | Value |
| --- | --- |
| Description | A candidate version receives the same inputs as the live version. Its actions are evaluated and recorded but never executed; tools return simulated or recorded responses. A compare view shows where the two versions behave differently. |
| Traces to | BR-16 |
| Release | v0.3 (Must) |

**User stories**

- As an engineer, I want to run version 2 next to version 1 for a week and see every place they differ before switching.
- As a lead, I want a simple summary: "v2 would have needed 30% fewer approvals and had 0 new blocks".

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-16.1 | Shadow mode flag on the SDK (`mode: "shadow"`) makes every action record-only; no tool is executed. | Must | v0.3 |
| FR-16.2 | Read-only tools may be allowed to execute in shadow if explicitly marked `side_effects: none`. | Should | v0.3 |
| FR-16.3 | Pairing: shadow traces are linked to live traces by a shared input id. | Must | v0.3 |
| FR-16.4 | Compare report: action differences, decision differences, approvals needed, blocks, cost and latency. | Must | v0.3 |
| FR-16.5 | Sampling: shadow only a percentage of traffic (default 10%). | Should | v0.3 |
| FR-16.6 | Interesting differences can be saved as cases in one click. | Should | v0.3 |

**Acceptance criteria**

- A test proves that in shadow mode a tool with side effects is never invoked, even if policy says allow.
- Shadow mode adds no latency to the live version's response path.
- Compare report for 1,000 paired traces renders in under 3 seconds.

# 11. Feature Requirements: Build

Build is what makes the loop feel like one product. It covers the CLI, framework adapters, the Python SDK, plugins, server mode and documentation: everything a developer touches to set up and grow AgentKeel.

### F-17  CLI and agentkeel init

| Attribute | Value |
| --- | --- |
| Description | The single command-line entry point. `init` creates a working setup in minutes by asking a few questions and writing one config file. Full command list in Section 14. |
| Traces to | BR-10, BR-25 |
| Release | v0.1 (Must) |

**User stories**

- As a new user, I want one command that sets everything up and shows me a blocked action.
- As a developer, I want every command to have `--help` with examples.

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-17.1 | `npx agentkeel init` detects project type (Node, Python, Claude Code, MCP config) and suggests packs. | Must | v0.1 |
| FR-17.2 | Writes `agentkeel.yaml` with comments, adds `.agentkeel/` to `.gitignore`. | Must | v0.1 |
| FR-17.3 | Offers a demo (`agentkeel demo`) that runs a fake agent and shows allow, ask and block live. | Should | v0.1 |
| FR-17.4 | Non-interactive mode with flags for scripts and CI. | Must | v0.1 |
| FR-17.5 | Errors follow a standard format: what happened, why, how to fix, link to docs. | Must | v0.1 |
| FR-17.6 | `agentkeel doctor` checks setup, versions and connectivity to notifiers. | Should | v0.1 |

**Acceptance criteria**

- In usability tests with 5 developers, median time from `init` to first blocked action is under 5 minutes.
- Every command returns exit code 0 on success and documented non-zero codes on failure.

### F-18  Framework adapters

| Attribute | Value |
| --- | --- |
| Description | Thin integrations so users of popular agent frameworks get AgentKeel without wrapping each tool by hand. |
| Traces to | BR-17 |
| Release | Claude Code v0.1; OpenAI Agents SDK and LangGraph v0.2; CrewAI and Vercel AI SDK v0.3 |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-18.1 | Claude Code: `agentkeel hooks install` configures PreToolUse and PostToolUse hooks that call the policy engine. | Must | v0.1 |
| FR-18.2 | OpenAI Agents SDK (TypeScript and Python) adapter. | Must | v0.2 |
| FR-18.3 | LangGraph adapter using its interrupt mechanism for approvals. | Must | v0.2 |
| FR-18.4 | CrewAI and Vercel AI SDK adapters. | Should | v0.3 |
| FR-18.5 | Adapter contract documented so the community can add more (via F-20). | Must | v0.2 |

**Acceptance criteria**

- Each adapter ships with an example project and an end-to-end test in CI against the framework's latest minor version.
- Adapter version support matrix is published in the docs.

### F-19  Python SDK

| Attribute | Value |
| --- | --- |
| Description | Feature parity with the TypeScript SDK for Protect and Observe, with Pythonic APIs (decorators and context managers). |
| Traces to | BR-15 |
| Release | v0.2 (Must) |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-19.1 | `@guard` decorator and `guard(fn)` function; sync and async supported. | Must | v0.2 |
| FR-19.2 | Same policy file, same event format, same store as TypeScript; both SDKs can share one project. | Must | v0.2 |
| FR-19.3 | Supports Python 3.11+ (all non-EOL versions); fully typed; published with Trusted Publishing. | Must | v0.2 |

**Acceptance criteria**

- A shared conformance test suite passes on both SDKs with identical decisions for 500 test actions.

### F-20  Plugin interface

| Attribute | Value |
| --- | --- |
| Description | A stable way for anyone to extend AgentKeel without changing the core: detectors (custom conditions), notifiers (approval channels), adapters, exporters, policy packs and attack suites. |
| Traces to | BR-21 |
| Release | Preview v0.2; stable v1.0 (Must) |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-20.1 | Plugin types: detector, notifier, adapter, exporter, pack, suite; each with a typed interface. | Must | v1.0 |
| FR-20.2 | Plugins declared in `agentkeel.yaml` by package name and version. | Must | v1.0 |
| FR-20.3 | `agentkeel plugin new <type>` scaffolds a plugin with tests and README. | Should | v1.0 |
| FR-20.4 | Plugin failures are isolated; a crashing detector results in its configured `on_error`, not a crash. | Must | v1.0 |

**Acceptance criteria**

- A first-time contributor can build and publish a notifier plugin in under 2 hours following the guide (tested with 3 people).

### F-21  Self-hosted server mode

| Attribute | Value |
| --- | --- |
| Description | For teams: one shared AgentKeel server (Docker image) that many agents report to, with shared dashboard, approvals and storage in Postgres. |
| Traces to | BR-20 |
| Release | v1.0 (Should) |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-21.1 | Official Docker image and Docker Compose file; SDKs connect with an API key. | Should | v1.0 |
| FR-21.2 | Postgres storage option; same event schema. | Should | v1.0 |
| FR-21.3 | Basic login (email magic link or OIDC) and roles: viewer, approver, admin. | Should | v1.0 |
| FR-21.4 | Local mode and server mode use the same dashboard code. | Must | v1.0 |

**Acceptance criteria**

- `docker compose up` gives a working server in under 3 minutes on a fresh machine.

### F-22  Documentation site and examples

| Attribute | Value |
| --- | --- |
| Description | A documentation site (GitHub Pages at agentkeel.github.io) and an examples folder with real, runnable protected agents. |
| Traces to | BR-25, BR-29 |
| Release | v0.1 (Must); grows each release |

**Functional requirements**

| ID | Requirement | Priority | Release |
| --- | --- | --- | --- |
| FR-22.1 | Quick start, concepts (the loop), guides per feature, policy reference, CLI reference, API reference. | Must | v0.1 |
| FR-22.2 | Examples: Claude Code + MCP, TypeScript support agent with refunds, Python agent (v0.2), shadow rollout (v0.3). | Must | v0.1 |
| FR-22.3 | Every code snippet in docs is tested in CI. | Should | v0.1 |
| FR-22.4 | README kept current with GIFs and screenshots for each release. | Must | v0.1 |

**Acceptance criteria**

- Docs search finds the right page for the 20 most common questions collected from design partners.

# 12. Policy Language Specification

The policy file is the product's main interface. It must be readable by someone who has never seen AgentKeel, strict enough to validate, and powerful enough for real rules. This section defines the language at product level; the TDD defines the parser.

*Example 12.1  A complete policy file*

```text
# agentkeel.yaml
version: 1
project: support-bot
extends:
  - agentkeel/payments@1          # policy pack, pinned to major version
default: ask                      # what happens when no rule matches
on_error: block                   # if a condition or plugin fails
approvers:
  leads: { slack: "#agent-approvals", telegram: [123456789] }

rules:
  - id: no-delete-prod
    match: { tool: "db.*", args: { operation: { in: [DELETE, DROP] } }, env: prod }
    effect: block
    reason: "Agents never delete production data"

  - id: big-refunds
    match: { tool: refund, args: { amount: { gt: 500 } } }
    effect: ask
    approvers: leads
    timeout: 10m
    on_timeout: block
    capture_case: true           # v0.2: rejection becomes a test case

  - id: read-only-tools
    match: { tool: [search_kb, get_order] }
    effect: allow

limits:
  - { tool: refund, budget: { sum: amount, max: 20000, per: 1d } }
  - { tool: "*", rate: { max: 60, per: 1m } }
redact: [api_key, password, "*.token", email]
```

## 12.1 Top-level keys

| Key | Type | Required | Meaning |
| --- | --- | --- | --- |
| `version` | integer | Yes | Policy language version; `1` for all v0.x releases. |
| `project` | string | Yes | Name used in events and the dashboard. |
| `extends` | list | No | Policy packs (name@major). Local rules override pack rules with the same id. |
| `default` | allow / ask / block | Yes | Effect when no rule matches. `init` sets `ask` for unknown tools. |
| `on_error` | allow / ask / block | No (block) | Effect when evaluation fails. |
| `approvers` | map | If any `ask` | Named approver groups and their channels. |
| `rules` | list | Yes | Ordered list of rules (see 12.2). |
| `limits` | list | No | Budgets, rate limits and loop detection. |
| `redact` | list | No | Extra argument keys or patterns to mask in events (defaults always apply). |
| `telemetry` | boolean | No (false) | Opt-in anonymous usage statistics (Section 13). |
| `plugins` | list | No | Plugins to load (v0.2 preview, v1.0 stable). |

## 12.2 Rule fields and operators

| Field | Meaning |
| --- | --- |
| `id` | Unique, stable rule id. Shown in every decision and used for overrides. |
| `match.tool` | Tool name, glob (`db.*`) or list. |
| `match.args` | Conditions on arguments using operators: `eq`, `ne`, `in`, `not_in`, `gt`, `gte`, `lt`, `lte`, `contains`, `matches` (regex), `exists`. |
| `match.agent`, `match.env`, `match.time` | Agent name or version, environment label, time windows (e.g., outside 09:00 to 19:00 IST). |
| `match.when` | v0.2: CEL-subset expression for anything not covered above. |
| `effect` | `allow`, `ask` or `block`. |
| `reason` | Human text shown to approvers, in denials returned to the agent and in the dashboard. |
| `approvers`, `timeout`, `on_timeout` | For `ask`: who decides, how long to wait (default 10m), what happens after (default block). |
| `capture_case` | v0.2: whether a block or rejection from this rule creates a case (default true). |

## 12.3 Evaluation order

- **1.** If the kill switch is active for this scope, the result is block. Nothing else is evaluated.
- **2.** Limits are checked (budget, rate, loop). A breached limit gives its effect (default block).
- **3.** All rules whose `match` is true are collected. If any says `block`, the result is block; else if any says `ask`, ask; else if any says `allow`, allow.
- **4.** If no rule matched, `default` applies.
- **5.** The decision records every matched rule id; the "winning" rule is shown first.

This "most restrictive wins" order is deliberate. Rule order in the file never changes safety, which removes a whole class of mistakes where a broad allow rule above a block rule silently disables it.

# 13. Telemetry and Privacy Behaviour

Trust is the product. AgentKeel sees every action an agent takes, often including customer data. Privacy behaviour is therefore a product requirement, not a legal footnote.

| Topic | Requirement |
| --- | --- |
| Default network use | The core loop (SDK, proxy, policy, store, dashboard, test) makes **zero** network calls except to notifiers the user configured. |
| Telemetry question | `agentkeel init` asks once: "Share anonymous usage statistics to help improve AgentKeel? (y/N)". Default **No**. Answer saved as `telemetry: true/false`. |
| Never asked | Non-interactive runs, CI (detected by `CI=true`) and `AGENTKEEL_TELEMETRY=0` never ask and never send. |
| What is sent if opted in | AgentKeel version, OS, Node or Python version, which features were used (counts), number of rules and packs, anonymous install id. Nothing else. |
| Never sent | Tool names, arguments, results, prompts, policy contents, approver identities, file paths, IP-derived location, any customer data. |
| Transparency | `agentkeel telemetry show` prints the exact payload that would be sent. The collector code and schema are public. |
| Redaction | Default patterns mask API keys, tokens, passwords, emails, phone numbers and card numbers before events are stored; users can add patterns. |
| Retention | Local events kept 30 days by default; configurable; pruning recorded in the audit chain. |
| Deletion | `agentkeel purge --session <id>` or `--before <date>` removes data and records a signed purge event (supports user data-deletion requests under laws such as India's DPDP Act). |

# 14. CLI Command Reference

Every command supports `--help`, `--json` output where it makes sense and documented exit codes. Commands are grouped by loop stage.

| Command | What it does | Stage | Release |
| --- | --- | --- | --- |
| `agentkeel init` | Interactive setup; writes `agentkeel.yaml`, detects project type, suggests packs. | Build | v0.1 |
| `agentkeel demo` | Runs a fake agent to show allow, ask and block live. | Build | v0.1 |
| `agentkeel check` | Validates the policy file; line-level errors. | Protect | v0.1 |
| `agentkeel explain <id>` | Shows how a decision was reached. | Protect | v0.1 |
| `agentkeel mcp wrap\|install` | Run an MCP server behind the proxy; rewrite MCP config. | Protect | v0.1 |
| `agentkeel hooks install` | Install Claude Code hooks. | Protect | v0.1 |
| `agentkeel approve\|reject <id>` | Decide a pending approval from the terminal. | Protect | v0.1 |
| `agentkeel kill\|resume [scope]` | Stop or resume actions. | Protect | v0.1 |
| `agentkeel ui` | Start the local dashboard. | Observe | v0.1 |
| `agentkeel tail` | Live stream of actions and decisions in the terminal. | Observe | v0.1 |
| `agentkeel verify` | Check the audit hash chain. | Observe | v0.1 |
| `agentkeel export` | Export events (JSONL; OTel and Langfuse in v0.3). | Observe | v0.1 |
| `agentkeel flag <id>` | Mark an allowed action as wrong; creates a case. | Learn | v0.2 |
| `agentkeel cases [list\|show\|edit]` | Manage the case library. | Learn | v0.2 |
| `agentkeel test [--suite]` | Replay cases and suites; CI-friendly output. | Test | v0.2 |
| `agentkeel simulate` | What-if for a policy change over past events. | Test | v0.3 |
| `agentkeel shadow [start\|compare]` | Run and compare shadow versions. | Shadow | v0.3 |
| `agentkeel doctor` | Diagnose setup problems. | Build | v0.1 |
| `agentkeel telemetry [show\|on\|off]` | See or change telemetry. | Build | v0.1 |
| `agentkeel purge` | Delete stored data by session or date. | Observe | v0.1 |
| `agentkeel plugin new <type>` | Scaffold a plugin. | Build | v1.0 |

# 15. Dashboard Screens

The dashboard follows the loop. Its left navigation has one item per stage so users learn the loop just by using the product.

| Screen | Purpose | Key elements | Release |
| --- | --- | --- | --- |
| Home | Health at a glance | Actions today, allowed / asked / blocked split, pending approvals, kill switch state, last test run | v0.1 |
| Activity (Observe) | Live feed of every action | Filters, decision badges with text labels, click to open trace | v0.1 |
| Trace | Full story of one run | Timeline of events, arguments (redacted), matched rules, approver, result, cost, "flag as wrong" | v0.1 |
| Approvals (Protect) | Decide pending actions | Queue with context, approve / reject with comment, history | v0.1 |
| Policies (Protect) | Understand active rules | Rules with hit counts, packs and versions, validation errors, link to file | v0.1 |
| Cases (Learn) | Manage captured knowledge | List, search, tags, expected outcome editor, source trace link | v0.2 |
| Tests (Test) | See replay and red-team results | Runs, pass / fail / flaky, diff per case, trend | v0.2 |
| Shadow | Compare versions | Paired traces, difference summary, save as case, promote checklist | v0.3 |
| Settings | Configure | Notifiers status, retention, telemetry, audit verify, export | v0.1 |

## 15.1 UX requirements for every screen

- **Empty states teach:** an empty screen explains what will appear and the one command that makes it appear.
- **Every decision explains itself:** blocked and asked actions always show the rule id and reason next to them.
- **Accessible:** keyboard navigation, visible focus, WCAG 2.1 AA contrast, status never shown by colour alone.
- **Light and dark themes** using the AgentKeel brand palette; works from 1280 px wide down to tablet width.
- **Fast:** first load under 1.5 seconds on localhost; no external fonts or scripts loaded from the internet.

# 16. Event Model Overview

All features share one event model. The full field-level definition will live in the Event Schema Specification; this table fixes the event types the product needs.

| Event type | Emitted when | Used by |
| --- | --- | --- |
| `session.started` / `session.ended` | An agent run begins or ends | Dashboard, replay grouping |
| `action.requested` | Agent attempts a tool call | All stages |
| `policy.decided` | Engine returns allow / ask / block | Protect, Learn, Test, Shadow |
| `approval.requested` / `approval.decided` / `approval.timed_out` / `approval.refused` | Approval lifecycle | Protect, audit, Learn |
| `action.executed` / `action.denied` | Tool runs or is stopped | Observe, Learn |
| `action.result` | Tool returns (redacted result, latency, cost) | Observe, replay mocks |
| `limit.breached` | Budget, rate or loop limit hit | Protect, dashboard |
| `kill.activated` / `kill.released` | Kill switch changes | Protect, audit |
| `case.created` / `case.updated` | Learn stage | Learn, Test |
| `test.run` / `test.case_result` | Test stage | Dashboard, CI |
| `shadow.paired` | A shadow trace is linked to a live trace | Shadow compare |
| `engine.error`, `retention.pruned`, `data.purged` | Operational and audit events | Audit, doctor |

# 17. Non-Functional Requirements

| ID | Category | Requirement | Target / how measured |
| --- | --- | --- | --- |
| NFR-01 | Performance | Policy evaluation overhead per action | p95 < 2 ms (200 rules); benchmark in CI fails on > 20% regression |
| NFR-02 | Performance | SDK end-to-end overhead excluding approvals | p95 < 5 ms in-process; < 10 ms via MCP proxy |
| NFR-03 | Performance | Event write throughput (local) | ≥ 2,000 events/second on a laptop |
| NFR-04 | Reliability | AgentKeel failure never crashes the host agent | Chaos tests: engine, store and notifier failures → `on_error` path |
| NFR-05 | Reliability | No lost decisions | 100% of `policy.decided` events persisted or reported as `engine.error` |
| NFR-06 | Security | Dashboard and local APIs bound to localhost with token | Pen-test checklist before each minor release |
| NFR-07 | Security | Approver authentication per channel | Only configured Slack/Telegram user IDs accepted |
| NFR-08 | Security | Supply chain | Signed releases, provenance, SBOM, pinned CI actions (BR-26) |
| NFR-09 | Privacy | No data leaves the machine by default | Network test in CI asserts zero outbound calls with default config |
| NFR-10 | Privacy | Secrets never stored | Redaction test corpus: 0 leaks |
| NFR-11 | Compatibility | Runtimes | Node 22+ (LTS), Bun 1.2+, Python 3.11+; Linux, macOS, Windows |
| NFR-12 | Compatibility | Backward compatibility | Events and policy v1 readable by every later 1.x release |
| NFR-13 | Footprint | Package size | TS SDK < 200 KB minified (excluding optional notifiers) |
| NFR-14 | Usability | Time to first protected action | Median < 5 minutes (usability tests) |
| NFR-15 | Accessibility | Dashboard | WCAG 2.1 AA |
| NFR-16 | Quality | Test coverage | Core packages ≥ 85% line coverage; policy engine ≥ 95% |
| NFR-17 | Maintainability | Public API stability | Semantic versioning; deprecations live ≥ 1 minor release with warnings |
| NFR-18 | Observability of AgentKeel itself | Debug logging | `AGENTKEEL_LOG=debug` gives structured logs without sensitive data |

# 18. Developer Experience and Documentation

For an open-source infrastructure project, developer experience is the marketing. These requirements apply across all features.

| Area | Requirement |
| --- | --- |
| README | Animated logo, one-sentence pitch, 30-second GIF of a blocked action, quick start in 3 commands, the loop diagram, badges (CI, version, downloads, license, OpenSSF Scorecard). Updated every release. |
| Errors | Format: `AK-<code>: what happened. Why. How to fix. Docs link.` Every error code has a docs page. |
| Defaults | Safe and useful without configuration. Every default is documented with the reason it was chosen. |
| Examples | Every feature has at least one runnable example; examples run in CI. |
| Changelog | Human-written highlights on top of automated changelog; breaking changes have migration steps. |
| API reference | Generated from types (TypeDoc, pdoc) and published with the docs site. |
| Contributor DX | One command to set up the repo (`pnpm i && pnpm dev`), tests run in under 2 minutes locally, `good first issue` labels maintained. |
| Support | GitHub Discussions for questions, Issues for bugs, response target 72 hours (BRD Section 9). |

# 19. Release Criteria

A release ships only when every item for that release is true. This list is copied into the release checklist issue template.

| Criterion | v0.1 | v0.2 | v0.3 | v1.0 |
| --- | --- | --- | --- | --- |
| All Must FRs for the release done and tested | ✓ | ✓ | ✓ | ✓ |
| NFR-01, 02, 04, 09, 10 passing in CI | ✓ | ✓ | ✓ | ✓ |
| Quick start verified on Linux, macOS and Windows | ✓ | ✓ | ✓ | ✓ |
| Docs and examples updated; README GIF refreshed | ✓ | ✓ | ✓ | ✓ |
| 5 design partners used the release candidate for 1 week | ✓ | ✓ |  |  |
| Security self-review checklist and dependency audit clean | ✓ | ✓ | ✓ | ✓ |
| Signed packages, provenance and SBOM |  | ✓ | ✓ | ✓ |
| Python SDK conformance suite passing |  | ✓ | ✓ | ✓ |
| QueueOS uses the release in staging |  |  | ✓ | ✓ |
| Event Schema and policy language frozen at 1.0 |  |  |  | ✓ |
| External security review (volunteer or sponsored) |  |  |  | ✓ |

# 20. Traceability Matrix

Every business requirement from the BRD is covered by at least one feature. BRs about process (community files, CI/CD) are covered by the SDLC Strategy and listed here for completeness.

| BR | Business requirement (short) | Covered by |
| --- | --- | --- |
| BR-01 | SDK interception | F-01, F-19 |
| BR-02 | MCP proxy | F-02 |
| BR-03 | Declarative policy | F-03, Section 12 |
| BR-04 | Human approvals | F-04 |
| BR-05 | Kill switch | F-05 |
| BR-06 | One event format | F-07, Section 16 |
| BR-07 | Tamper-evident audit | F-08 |
| BR-08 | Local dashboard | F-09, Section 15 |
| BR-09 | Policy packs | F-06 |
| BR-10 | Five-minute setup | F-17, NFR-14 |
| BR-11 | Mistakes become cases | F-11 |
| BR-12 | Replay | F-12 |
| BR-13 | Red-team suite | F-13 |
| BR-14 | CI integration | F-14 |
| BR-15 | Python SDK | F-19 |
| BR-16 | Shadow mode | F-16 |
| BR-17 | Framework adapters | F-18 |
| BR-18 | Export to OTel / Langfuse | F-10 |
| BR-19 | Policy simulation | F-15 |
| BR-20 | Self-hosted server | F-21 |
| BR-21 | Plugin interface | F-20 |
| BR-22 | Event Schema Spec | F-07, Event Schema Spec doc |
| BR-23 | Low overhead | NFR-01, NFR-02 |
| BR-24 | Local by default, opt-in telemetry | Section 13, NFR-09 |
| BR-25 | Documentation site | F-22, Section 18 |
| BR-26 | Signed releases, SBOM | NFR-08, SDLC Strategy |
| BR-27 | Community health files | SDLC Strategy, repo files |
| BR-28 | CI/CD and bots | SDLC Strategy |
| BR-29 | Examples | F-22 |
| BR-30 | Stable 1.0 API | NFR-12, NFR-17, Section 19 |

# 21. Product Risks and Mitigations

Business risks are in the BRD. These are risks to the product itself: things that could make users uninstall AgentKeel.

| Risk | Why it matters | Mitigation in this PRD |
| --- | --- | --- |
| Too many approval requests ("approval fatigue") | Users turn `ask` into `allow` and lose protection. | Packs tuned to ask rarely; hit counts on Policies screen; shadow compare shows approvals needed; simulation before changes. |
| Slows agents down | Developers remove it from the hot path. | NFR-01/02 benchmarks in CI; async event writes; no network on the decision path. |
| False sense of safety | Users trust it beyond what it does. | Docs "What AgentKeel does not protect against" page; non-goals in Section 2.2; red-team suite shows gaps. |
| Breaks the agent | One crash ends trust. | NFR-04 chaos tests; `on_error`; isolated plugins. |
| Leaks sensitive data | Security product leaking data is fatal. | Default redaction; local store; zero network by default; secret tests (NFR-10). |
| Scope creep across six stages | Nothing gets finished. | Strict release matrix (Section 5.1); Must lists small; later stages only after earlier ones are solid. |
| Framework churn | Adapters break when frameworks change. | Thin adapters; CI against latest versions; community-owned adapters through plugins. |

# 22. Open Questions and Next Steps

| # | Question | Decide by |
| --- | --- | --- |
| PQ1 | Default `default:` effect for brand-new projects: `ask` (safer, noisier) or `allow` with packs (smoother)? Proposed: `ask` for unknown tools, revisit after design-partner feedback. | Jan 2027 |
| PQ2 | Dashboard technology: same stack as QueueOS (Next.js) or a lighter bundled single-page app? Proposed: lightweight bundled app (decided in TDD). | TDD |
| PQ3 | Should `ask` also support "approve and remember for this session"? | v0.2 planning |
| PQ4 | Which 3 additional policy packs in v0.2 (cloud CLI, database, browser agent)? | Feb 2027 |
| PQ5 | Is Telegram approval enough for Indian design partners, or is WhatsApp needed (paid API)? | Design partner calls |

## 22.1 Next steps

- **1. Review this PRD** and freeze v0.1 scope.
- **2. Write the SDLC Strategy:** repository setup, CI/CD, bots, branch protection, release automation, supply-chain security.
- **3. Write the TDD and Event Schema Spec:** architecture, packages, storage, interfaces.
- **4. Tech Stack document, community files and the Claude Code build prompt pack.**
- **5. Start the v0.1 build in December 2026**, feature by feature in the order F-03 → F-01 → F-07 → F-17 → F-02 → F-04 → F-05 → F-09 → F-08 → F-06 → F-18 → F-22.

# 23. Appendix

## 23.1 Glossary

| Term | Meaning |
| --- | --- |
| Action | One attempt by an agent to call a tool. |
| Policy | The rules in `agentkeel.yaml` that decide allow, ask or block. |
| Policy pack | A reusable, versioned set of rules for a common agent type. |
| Case | A saved action with context and expected outcome, used for testing. |
| Replay | Re-running cases or recordings against a new agent version or policy. |
| Shadow | Running a candidate version on real inputs without executing its actions. |
| MCP | Model Context Protocol: an open standard for connecting AI applications to tools and data. |
| Hash chain | Each record includes the hash of the previous one, so any change is detectable. |
| CEL | Common Expression Language: a small, safe expression language for conditions. |
| Trusted Publishing | Publishing packages from CI using short-lived identity tokens instead of stored passwords. |

## 23.2 Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Product owner and lead maintainer | Ashutosh Kumar Rao | Pending review |  |
| Design partner reviewers (5) | To be named | Feedback |  |
