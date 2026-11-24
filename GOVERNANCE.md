# AgentKeel Governance

AgentKeel is an open-source project licensed under Apache-2.0. This document
explains how decisions are made and how people gain responsibility.

## Principles

- **Open by default.** Discussions, decisions and roadmaps happen in public
  (issues, Discussions, RFCs, ADRs). Only security and Code of Conduct matters
  are private.
- **Merit and care.** Responsibility follows sustained, high-quality
  contributions and kindness to others, not employer or seniority.
- **Users first.** Safety and backward compatibility outweigh convenience.

## Roles

| Role | Who | Can |
|------|-----|-----|
| Contributor | Anyone who opens an issue, PR, review or discussion | Propose anything |
| Triager | Invited regular contributors | Label, close duplicates, request info |
| Maintainer | Listed in [MAINTAINERS.md](MAINTAINERS.md) | Review and merge PRs, approve releases in their areas |
| Lead maintainer | Ashutosh Kumar Rao | Roadmap, final decisions, security and conduct escalation |

## Becoming a maintainer

1. Sustained contributions for about 3 months (code, reviews, docs or triage).
2. Nominated by a maintainer in a private maintainer discussion.
3. No objection from existing maintainers within 7 days (lazy consensus).
4. Added to MAINTAINERS.md and CODEOWNERS for their areas.

Maintainers inactive for 6 months move to emeritus status, with thanks. They can
return by asking.

## Decision making

- **Everyday changes:** one maintainer approval and green CI.
- **Public API, policy language, event schema, licence, governance:** an RFC
  issue open at least 7 days, then a decision recorded as an ADR. Lazy
  consensus among maintainers; if there is an unresolved objection, the lead
  maintainer decides and records the reasoning.
- **Security fixes:** handled privately by maintainers (see SECURITY.md).

As the project grows to five or more maintainers, the lead-maintainer model will
be replaced by a steering group elected by maintainers. That change itself will
follow the RFC process.

## Open-core promise

The full AgentKeel loop (Protect, Observe, Learn, Test, Shadow, Build), SDKs,
CLI, dashboard, self-hosted server and the event schema stay open source under
Apache-2.0. Any future paid offering (for example a hosted cloud or enterprise
SSO) is additive and will never remove or cripple open features.

## Trademarks

The name and logo are governed by [TRADEMARKS.md](TRADEMARKS.md).

## Contributions and licensing

Contributions are accepted under Apache-2.0 with a Developer Certificate of
Origin sign-off on every commit. There is no CLA.
