<div align="center">

<img alt="AgentKeel" src="AgentKeel_Logo_Animated.gif" width="420">

### The open-source stability layer for AI agents

**Protect. Observe. Learn. Test. Shadow. Build.**<br>
*One loop. One install. One place.*

[![CI](https://github.com/agentkeel/agentkeel/actions/workflows/ci.yml/badge.svg)](https://github.com/agentkeel/agentkeel/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/agentkeel/agentkeel/badge)](https://scorecard.dev/viewer/?uri=github.com/agentkeel/agentkeel)
[![npm](https://img.shields.io/npm/v/agentkeel?label=npm&color=0F172A)](https://www.npmjs.com/package/agentkeel)
[![PyPI](https://img.shields.io/pypi/v/agentkeel?label=pypi&color=0F172A)](https://pypi.org/project/agentkeel/)
[![License](https://img.shields.io/badge/license-Apache--2.0-0E7490)](LICENSE)
[![Status](https://img.shields.io/badge/status-early%20design-EA580C)](#roadmap)
[![GitHub stars](https://img.shields.io/github/stars/agentkeel/agentkeel?style=flat&color=0E7490)](https://github.com/agentkeel/agentkeel/stargazers)

🚧 **Early design. Not ready for use yet.** Star or watch the repo to follow along.

[Website](https://agentkeel.github.io) · [Roadmap](ROADMAP.md) · [Contributing](CONTRIBUTING.md) · [Discussions](https://github.com/agentkeel/agentkeel/discussions)

</div>

---

## Why AgentKeel?

AI agents don't just talk anymore. They **act**: they delete files, send emails, call APIs, move money and change databases.

To make an agent safe and reliable today, teams stitch together 3 to 5 separate tools: one for guardrails, one for tool-call policies, one for human approvals, one for tracing, and one for evals. None of them talk to each other:

- A blocked action never becomes a test case, so the same mistake happens again.
- Rules live in several config files.
- No single place shows the full story: *what went in, what the agent tried, who approved it, what happened.*

**AgentKeel puts the whole agent reliability lifecycle in one open-source place.**

## The AgentKeel loop

```
        ┌──────────────►  BUILD  ───────────────┐
        │     (agents, tools, policies)          │
        │                                        ▼
      LEARN                                    TEST
  (mistakes become tests)             (replay, red-team, CI)
        ▲                                        │
        │                                        ▼
     OBSERVE                                  SHADOW
  (traces, audit, cost)                (run on real data, change nothing)
        ▲                                        │
        │                                        ▼
        └──────────────  PROTECT (live)  ◄───────┘
           (policies, approvals, blocks, kill switch)
```

Everything shares one open [event format](https://agentkeel.github.io). An action blocked in **Protect** shows up in **Observe**, becomes a case in **Learn**, runs against the next version in **Test**, and is verified in **Shadow** before going live.

## A taste of what's coming

> ⚠️ Design preview. Names may still change before v0.1.

```yaml
# agentkeel.yaml
version: 1
project: support-bot
extends: [agentkeel/payments@1]      # ready-made policy pack
default: ask                         # unknown tools need a human
approvers:
  leads: { slack: "#agent-approvals", telegram: [123456789] }

rules:
  - id: no-delete-prod
    match: { tool: "db.*", args: { operation: { in: [DELETE, DROP] } }, env: prod }
    effect: block
    reason: "Agents never delete production data"

  - id: big-refunds
    match: { tool: refund, args: { amount: { gt: 500 } } }
    effect: ask                      # approve in one tap on Slack or Telegram
    approvers: leads

limits:
  - { tool: refund, budget: { sum: amount, max: 20000, per: 1d } }
```

```ts
import { guardAll } from "@agentkeel/sdk";

const tools = guardAll({ refund, searchOrders, sendEmail });  // one line, every tool protected
```

## Planned features

| Stage | What you get |
|---|---|
| **Protect** | Policy file for agent actions (allow / ask a human / block), approvals via Slack, Telegram, CLI or dashboard, kill switch, budgets and rate limits, MCP proxy, Claude Code hooks |
| **Observe** | Full trace of every action in a hash-chained, tamper-evident log; cost and latency per agent; local dashboard |
| **Learn** | Blocked and rejected actions turn into test cases automatically |
| **Test** | Replay past actions against new versions, prompt-injection red-team suite, GitHub Action for CI |
| **Shadow** | Run a new agent version on real traffic in record-only mode and compare |
| **Build** | One config, one CLI, one dashboard, Python and TypeScript SDKs, plugins for popular agent frameworks |

## Install (coming with v0.1)

> 🚧 The packages below are **name placeholders** today. Installing them does nothing yet.

```bash
npx agentkeel init      # Node.js / TypeScript
pip install agentkeel   # Python (from v0.2)
```

## Principles

- **One place:** one install, one config, one CLI, one dashboard.
- **Safe by default:** if anything fails, risky actions are blocked, never silently allowed.
- **Local first:** your data stays on your machine; telemetry is off unless you opt in.
- **Neutral:** works with any model, any framework, any cloud. Self-hostable.
- **Simple:** from install to first protected agent in about 5 minutes.

## Roadmap

- [x] Name, packages and project home reserved
- [x] Product and technical design (BRD, PRD, SDLC, TDD, Event Schema)
- [ ] **v0.1 (Mar 2027):** Protect + Observe
- [ ] **v0.2 (Apr 2027):** Learn + Test, Python SDK
- [ ] **v0.3 (Jul 2027):** Shadow mode
- [ ] **v1.0 (Q4 2027):** stable API, self-hosted server, plugins

Details in [ROADMAP.md](ROADMAP.md).

## Contributing

AgentKeel is built in public and contributions are welcome: code, docs, policy packs, plugins, red-team cases and feedback.

- Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md)
- Pick a [`good first issue`](https://github.com/agentkeel/agentkeel/labels/good%20first%20issue)
- Ask questions in [Discussions](https://github.com/agentkeel/agentkeel/discussions)

**Security issues:** please report privately, see [SECURITY.md](SECURITY.md).

## Community and project

| | |
|---|---|
| [GOVERNANCE.md](GOVERNANCE.md) | How decisions are made, how to become a maintainer, the open-core promise |
| [SUPPORT.md](SUPPORT.md) | Where to get help |
| [TRADEMARKS.md](TRADEMARKS.md) | Using the AgentKeel name and logo |
| [CHANGELOG.md](CHANGELOG.md) | What changed in each release |

## License

[Apache License 2.0](LICENSE). The AgentKeel name and logo are covered by the [trademark policy](TRADEMARKS.md).

---

<div align="center">
<sub>Built by <a href="https://github.com/ASHUTOSH-KUMAR-RAO">Ashutosh Kumar Rao</a> and <a href="https://github.com/agentkeel/agentkeel/graphs/contributors">contributors</a></sub>
</div>
