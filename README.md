<div align="center">

# AgentKeel

### The open-source stability layer for AI agents

**Protect. Observe. Learn. Test. Shadow. Build.**
*One loop. One install. One place.*

🚧 **Status: early design. Not ready for use yet.** Star or watch the repo to follow along.

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
  (mistakes become tests)             (evals, red-team, simulation)
        ▲                                        │
        │                                        ▼
     OBSERVE                                  SHADOW
  (traces, audit, cost)                (run on real data, change nothing)
        ▲                                        │
        │                                        ▼
        └──────────────  PROTECT (live)  ◄───────┘
           (policies, approvals, blocks, kill switch)
```

Everything shares one data model. An action blocked in **Protect** shows up in **Observe**, becomes a case in **Learn**, runs against the next version in **Test**, and is verified in **Shadow** before going live.

## Planned features

| Stage | What you get |
|---|---|
| **Protect** | Policy file for agent actions (allow / ask a human / block), approvals via Slack or Telegram, kill switch, MCP proxy |
| **Observe** | Full trace of every action with a tamper-evident audit log, cost and latency per agent |
| **Learn** | Blocked and rejected actions turn into regression tests automatically |
| **Test** | Evals, prompt-injection red-team suite, replay past actions against new versions, CI integration |
| **Shadow** | Run a new agent version on real traffic in record-only mode |
| **Build** | One config, one CLI, one dashboard, with plugins for popular agent frameworks |

## Principles

- **One place:** one install, one config, one CLI, one dashboard.
- **Neutral:** works with any model, any framework, any cloud. Self-hostable.
- **Simple:** from install to first protected agent in about 5 minutes.
- **Plug-in, not lock-in:** keep the tools you already use; AgentKeel connects to them.

## Roadmap

- [ ] **v0.1:** Protect + Observe
- [ ] **v0.2:** Learn + Test (the mistake-to-test loop)
- [ ] **v0.3:** Shadow mode
- [ ] **v1.0:** Build + framework integrations

## Follow along

- ⭐ Star this repo to get updates
- 👀 Watch for releases
- 💬 Ideas and feedback: open an issue

## License

To be decided before the first release.

---

<div align="center">
Built by <a href="https://github.com/ASHUTOSH-KUMAR-RAO">Ashutosh Kumar Rao</a>
</div>
