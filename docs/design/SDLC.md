# AgentKeel SDLC Strategy v1.0

> Markdown copy of the Word document for use by contributors and Claude Code. The Word/PDF version is the formatted original; diagrams are in `flows/`.

# 1. Document Overview

This document defines the **Software Development Life Cycle (SDLC)** for AgentKeel: how work is chosen, how code is written and reviewed, how it is tested, how it reaches users and how the project stays secure and healthy for years. It turns BRD requirements BR-26 (signed releases), BR-27 (community health files) and BR-28 (CI/CD, bots and release process) into concrete rules, tools and settings.

AgentKeel is a security-relevant open-source project. Users put it in front of agents that can delete data or move money. That raises the bar: the way AgentKeel is built must itself be trustworthy, reviewable and reproducible. Every practice here is standard in mature open-source projects (Kubernetes, Node.js, OpenTelemetry, Sigstore) and is scaled down so one maintainer with a free GitHub account can run it.

## 1.1 Scope

| Covered here | Covered elsewhere |
| --- | --- |
| Process model, planning cycles, roles and rigor levels | What to build: PRD v1.0 |
| Repository layout, branching, commits, pull requests, reviews | How it is built inside: TDD and Event Schema Spec |
| Testing strategy, CI pipeline, bots, dependency policy | Which technologies and why: Tech Stack document |
| Release process, versioning, supply-chain security, vulnerability handling | Community file texts: repository files kit (CONTRIBUTING, SECURITY, …) |
| Documentation workflow, community operations, AI-assisted development policy | Business goals and KPIs: BRD v1.0 |

## 1.2 Guiding sources

- **OpenSSF Scorecard and Best Practices Badge** for repository security checks.
- **SLSA (Supply-chain Levels for Software Artifacts)** for build provenance targets.
- **Conventional Commits 1.0** and **Semantic Versioning 2.0** for history and versions.
- **DORA metrics** for delivery performance; **CHAOSS** metrics for community health.
- **GitHub's open-source guides** for community health files and governance.
- **System flows 1 to 4** (pages after the contents) show the contribution, CI, release and vulnerability flows at a glance; this text explains each in depth.

# 2. SDLC at a Glance

The whole SDLC fits in one sentence: **small changes, always green `main`, everything automated except judgement.**

1. **Plan** – 2-week cycle, issues
2. **Build** – Branch, small PR
3. **Verify** – CI + review
4. **Merge** – Queue, squash
5. **Release** – Release Please
6. **Operate** – Triage, security

| Principle | What it means in practice |
| --- | --- |
| Trunk-based development | One long-lived branch (`main`). Short branches, merged within days, never weeks. |
| Main is always releasable | Every merge passed the full CI matrix in the merge queue. Unfinished features hide behind flags or `experimental` exports. |
| Automate the boring, keep people for judgement | Bots label, remind, update dependencies, write changelogs and publish. People decide scope, review design and approve releases. |
| Security is part of the pipeline | Pinned actions, least-privilege tokens, OIDC publishing, provenance and SBOM on every release, not as an afterthought. |
| Docs are part of done | A feature is not done until its docs page, example and changelog entry exist. |
| Be kind and fast to contributors | First response within 72 hours, clear labels, good first issues and a welcoming tone. |
| Dogfood the product | Claude Code used on this repository runs behind AgentKeel itself from v0.1. |

# 3. Process Model

AgentKeel uses a hybrid model sized for one maintainer plus a growing community. It is the same family of practices used for QueueOS (Lean + Shape-Up cycles + Kanban + Continuous Delivery), adapted to open source where contributors come and go.

| Practice | How AgentKeel uses it | Why |
| --- | --- | --- |
| Shape-Up style cycles | 2-week build cycles with a fixed scope "bet". Cycle plan posted as a GitHub Discussion and a milestone. | Fixed time, flexible scope keeps a solo maintainer shipping instead of drifting. |
| Kanban flow | GitHub Project board: Triage → Ready → In progress → In review → Done. WIP limit 2 for the maintainer. | Makes work visible to contributors; limits context switching. |
| Cool-down week | After every 3 cycles: 1 week for bugs, docs, dependency updates, community issues. | Prevents burnout and keeps the backlog healthy. |
| RFCs for big changes | Changes to public API, policy language or event schema need an RFC issue with 7 days for comments, then an ADR. | Protects users from surprise breaking changes; invites community input. |
| Continuous Delivery | Release PR always ready; releases every cycle or sooner for fixes. | Users get fixes fast; small releases are low risk. |

## 3.1 Roles

| Role | Who (now) | Responsibilities |
| --- | --- | --- |
| Lead maintainer | Ashutosh Kumar Rao | Roadmap, cycle bets, final review, releases, security response, Code of Conduct enforcement. |
| Maintainers | Added from active contributors (see GOVERNANCE.md) | Review and merge, triage rotation, release approval for their areas. |
| Contributors | Anyone | Issues, PRs, docs, policy packs, plugins, discussions. |
| Design partners | 5 early users | Test release candidates for a week; give structured feedback. |
| Bots | GitHub Actions and apps | Everything in Section 9: labels, checks, updates, changelogs, publishing. |

## 3.2 Rigor levels

Not all code carries the same risk. Each package has a rigor level that sets its review, testing and change rules. This keeps the bar very high where safety lives and lighter where it does not.

| Level | Packages | Rules |
| --- | --- | --- |
| L1 Critical | `policy`, `core` decision pipeline, redaction, hash chain, approvals state machine | Two reviews once a second maintainer exists; ≥ 95 % line coverage; property tests; mutation score ≥ 80 %; benchmarks; ADR for any behaviour change. |
| L2 Important | `sdk`, `hub` API, `mcp-proxy`, store adapters, notifiers | ≥ 85 % coverage; contract tests against OpenAPI and event schema; e2e on 3 OS. |
| L3 Standard | `cli`, `dashboard`, adapters, test runner | ≥ 75 % coverage; e2e happy paths; accessibility checks for UI. |
| L4 Light | Docs site, examples, scripts | Builds and runs in CI; links checked; examples smoke-tested. |

## 3.3 Definition of Ready and Definition of Done

| Definition of Ready (before work starts) | Definition of Done (before merge) |
| --- | --- |
| Issue has a clear problem, acceptance criteria and a PRD feature or BR link. | All acceptance criteria met and covered by tests at the package's rigor level. |
| Size label set (S, M, L); L items split or shaped first. | CI green in the merge queue, including benchmarks and security checks. |
| Design notes or ADR exist for L1 changes. | Docs page, example and changelog-worthy PR title written. |
| No open question that blocks implementation. | No new `TODO` without a linked issue; no disabled tests. |

# 4. Repository and Monorepo Structure

AgentKeel lives in one public repository, `agentkeel/agentkeel`, as a **pnpm workspace monorepo** managed with **Turborepo**. A monorepo keeps the SDK, Hub, CLI, dashboard and event schema in lock-step, makes cross-package changes one PR, and lets CI test exactly what changed. The Python SDK lives in the same repository so the conformance suite can test both SDKs together.

*Figure 4.1  Repository layout*

```text
agentkeel/
├── .github/            workflows, issue forms, PR template, CODEOWNERS, dependabot, labeler
├── packages/
│   ├── spec/           event JSON Schemas + policy schema + generated types   (L1)
│   ├── policy/         parser, compiler, evaluator (pure, no I/O)              (L1)
│   ├── core/           decision pipeline, approvals, limits, ports             (L1)
│   ├── sdk/            @agentkeel/sdk: guard(), buffer, spool, hub client      (L2)
│   ├── hub/            Keel Hub: HTTP API, ingest, workers                     (L2)
│   ├── store-sqlite/   SQLite adapter + migrations                             (L2)
│   ├── store-postgres/ Postgres adapter (v1.0)                                 (L2)
│   ├── mcp-proxy/      MCP stdio / HTTP proxy                                  (L2)
│   ├── notifiers/      slack, telegram, email, webhook                         (L2)
│   ├── testkit/        replay runner, cassettes, red-team suites               (L3)
│   ├── adapters/       claude-code, openai-agents, langgraph, …                (L3)
│   ├── cli/            agentkeel CLI (bin), init, doctor                       (L3)
│   └── dashboard/      Vite + React SPA, bundled into hub                      (L3)
├── python/agentkeel/   Python SDK (uv, hatchling)                              (L2)
├── conformance/        shared decision test vectors for TS + Python
├── packs/              official policy packs (coding-agent, payments, …)
├── examples/           runnable protected agents (tested in CI)
├── docs/               Astro Starlight site → GitHub Pages
├── adr/                architecture decision records (0001-….md)
├── rfcs/               accepted RFCs
└── README.md, LICENSE, NOTICE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md,
    SUPPORT.md, GOVERNANCE.md, MAINTAINERS.md, ROADMAP.md, CHANGELOG.md, TRADEMARKS.md
```

Package boundaries follow the hexagonal architecture in the TDD: `policy` and `core` must not import any I/O package. A dependency-rule check (dependency-cruiser) runs in CI and fails if a lower layer imports a higher one.

# 5. Branching, Commits and Pull Requests

System flow 1 shows the full contribution lifecycle. The rules below make it enforceable.

## 5.1 Branching model

| Branch | Purpose | Rules |
| --- | --- | --- |
| `main` | Single source of truth; always releasable | Protected by a repository ruleset: PR required, 1 approval, `ci-ok` required, merge queue, linear history, no force push, no deletion. |
| `feat/…`, `fix/…`, `docs/…` | Short-lived work branches (from forks for external contributors) | Live ≤ 5 days; rebased or updated by the merge queue. |
| `release-please--…` | Release PR branch owned by the bot | Only Release Please writes to it. |
| `hotfix/vX.Y` | Patch an older supported minor | Created from the release tag only when needed; same CI and release flow. |

## 5.2 Commit and PR title convention

PRs are **squash-merged**, so the PR title becomes the commit on `main`. Titles follow **Conventional Commits** and are checked by a PR-title workflow:

*Figure 5.1  Commit format*

```text
<type>(<scope>)!: <summary in imperative mood>

type  = feat | fix | perf | refactor | docs | test | build | ci | chore | deps | revert
scope = policy | core | sdk | hub | cli | dashboard | mcp | notifiers | spec | python | packs | docs
!     = breaking change (also add "BREAKING CHANGE:" in the PR body)

examples:
feat(policy): add matches operator for regex conditions
fix(mcp)!: return MCP error result instead of throwing on denial
```

`feat` creates a minor release, `fix`, `perf` and `deps` a patch, and `!` a breaking release (minor while 0.x, major from 1.0). Every commit must carry a **DCO sign-off** (`Signed-off-by:` line, added with `git commit -s`), checked by the DCO GitHub App.

## 5.3 Pull request rules

- **Small:** aim for under 400 changed lines excluding generated files; split larger work behind a flag.
- **Linked:** every PR links an issue (`Fixes #123`) except typo fixes.
- **Template:** what and why, how tested, screenshots for UI, checklist (tests, docs, changelog title, breaking change notes).
- **Review:** CODEOWNERS request the right reviewer automatically. Reviews look at correctness, safety, API shape, tests and docs, in that order.
- **Response time:** first review within 72 hours; contributors are told clearly if a PR will not be accepted.
- **Merge queue:** approved PRs enter the queue, are re-tested against the latest `main`, then squash-merged. This removes "it was green yesterday" breakages.

## 5.4 Code review checklist

| Area | Reviewer asks |
| --- | --- |
| Safety | Can this change ever let a blocked action run? Does every failure path end in `on_error`? Are secrets redacted before storage? |
| API | Is any public API, CLI flag, policy key or event field changed? If yes, is there an RFC/ADR, a migration note and a deprecation path? |
| Tests | Are tests at the right level for the rigor level? Do they fail without the change? |
| Performance | Does anything new run on the decision path? Did benchmarks move? |
| Docs | Is the docs page updated? Is the error message helpful (what, why, fix, link)? |
| Licensing | Any new dependency? Is its licence on the allowlist (Section 10)? |

# 6. Code Quality Standards

| Area | Standard | Enforced by |
| --- | --- | --- |
| Language | TypeScript `strict` with `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`; ESM-first, dual ESM/CJS output for SDK. | `tsc --build` in CI |
| Formatting and lint | Biome for format + lint (one fast tool); Ruff for Python. | Biome and Ruff in CI; lefthook pre-commit |
| Types for Python | Fully typed, `py.typed` marker; Pyright strict. | Pyright in CI |
| Public API | Every exported symbol has TSDoc; API report checked so accidental API changes fail CI. | API Extractor report diff |
| Errors | Typed errors with stable codes `AK-xxxx`; message = what, why, fix, docs link. | Unit tests + error catalogue test |
| Logging | Structured (pino); never log raw arguments, secrets or tokens. | Redaction tests + review |
| Dependencies | Prefer no dependency; every new runtime dependency justified in the PR. | Dependency review action, Knip for unused deps |
| Architecture | Hexagonal layers; domain packages free of I/O. | dependency-cruiser rules |
| Bundle size | SDK < 200 KB minified (NFR-13). | size-limit check |
| Decisions | Significant decisions recorded as ADRs (MADR format) in `adr/`. | Review checklist |

# 7. Testing Strategy

Testing is shaped like a pyramid with two extra layers that matter for a safety product: **property tests** for the policy engine and **conformance tests** that keep TypeScript and Python SDKs identical.

| Layer | What it covers | Tools | Runs |
| --- | --- | --- | --- |
| Unit | Pure functions: parser, compiler, evaluator, redaction, hash chain, state machines | Vitest, pytest | Every PR (< 60 s) |
| Property-based | Engine invariants: order independence, "adding a block rule never loosens", redaction never leaks test secrets | fast-check, Hypothesis | Every PR |
| Mutation | Quality of L1 tests (do tests catch injected bugs?) | StrykerJS | Nightly, L1 packages |
| Contract | Hub API matches OpenAPI; events match JSON Schemas; CLI JSON output stable | Schemathesis, Ajv, snapshot tests | Every PR |
| Conformance | 500+ decision vectors: same input → same decision in TS and Python | Shared YAML vectors | Every PR |
| Integration | SDK ↔ Hub ↔ SQLite; notifiers against local fakes; MCP proxy with a real MCP server | Vitest, testcontainers (Postgres) | Every PR |
| End-to-end | Quick start on 3 OS; dashboard flows; Claude Code hook flow | Playwright, scripted shells | Every PR (smoke), nightly (full) |
| Performance | NFR-01/02/03 budgets: decision p95, ingest throughput | tinybench/mitata, k6 for Hub | Every PR (compare to main) |
| Chaos and failure | Hub down, disk full, notifier timeout, corrupted policy, crash mid-batch | Fault-injection harness | Nightly |
| Security | Secrets, SAST, dependency CVEs, fuzzing of policy parser and MCP framing | CodeQL, gitleaks, Dependabot, Jazzer.js fuzz | Every PR / weekly fuzz |

## 7.1 Coverage and quality gates

- **Line coverage:** L1 ≥ 95 %, L2 ≥ 85 %, L3 ≥ 75 %. Patch coverage ≥ 80 % on every PR (Codecov).
- **Mutation score:** L1 packages ≥ 80 % (nightly; a drop opens an issue automatically).
- **Flaky tests:** a flaky test is quarantined within 24 hours with an issue and fixed within one cycle. Retrying until green is not allowed.
- **Test data:** a shared "redaction corpus" of fake secrets (API keys, tokens, Indian phone numbers, card numbers) is used across tests to prove nothing leaks.

# 8. Continuous Integration

System flow 2 shows the CI pipeline. Every pull request and every merge-queue run executes the same workflow, so what is tested is exactly what is merged.

| Job | What it runs | Matrix | Budget |
| --- | --- | --- | --- |
| `lint` | Biome, Ruff, commitlint on PR title, actionlint on workflows, markdown links | 1 job | < 1 min |
| `typecheck` | `tsc --build`, Pyright, API Extractor report | 1 job | < 2 min |
| `test-ts` | Vitest unit, property, integration, conformance | Ubuntu, macOS, Windows × Node 22, 24 | < 5 min |
| `test-py` | pytest, Hypothesis, conformance | Ubuntu × Python 3.11, 3.12, 3.13, 3.14 | < 4 min |
| `build` | tsup builds, dashboard build, size-limit, `pnpm pack` dry run | 1 job | < 3 min |
| `e2e` | Quick-start smoke, Playwright dashboard, MCP proxy with reference server | Ubuntu (+ 3 OS nightly) | < 6 min |
| `bench` | Decision and ingest benchmarks compared with `main` | Ubuntu | < 4 min |
| `security` | CodeQL (JS/TS, Python), dependency review, gitleaks | 1 job each | < 8 min |
| `ci-ok` | Aggregates all needed jobs into one required status | — | seconds |

## 8.1 CI engineering rules

- **Speed:** pnpm store cache and Turborepo task cache; affected-only runs for docs-only changes; `concurrency` cancels superseded runs. Target: PR feedback under 10 minutes.
- **Least privilege:** workflow default `permissions: contents: read`; jobs request write scopes only when required (e.g. PR comment).
- **Pinned actions:** every third-party action pinned to a full commit SHA with the version in a comment; Dependabot keeps them current.
- **Hardening:** `step-security/harden-runner` audits outbound network calls from CI jobs.
- **Fork safety:** PRs from forks run without secrets. `pull_request_target` is never used to check out or run PR code.
- **Reproducibility:** lockfiles committed (`pnpm-lock.yaml`, `uv.lock`); `--frozen-lockfile` in CI.

# 9. Bots and Automation

Bots do repetitive work so the maintainer's time goes to design, review and community. Every bot below is free for public repositories.

| Bot / workflow | Job | Trigger | Config file |
| --- | --- | --- | --- |
| Dependabot version updates | Weekly grouped PRs for npm, pip/uv, GitHub Actions; security updates immediately | Schedule + advisories | `.github/dependabot.yml` |
| Release Please | Keeps a release PR with versions and CHANGELOG per package; tags and GitHub Releases on merge | Push to `main` | `release-please-config.json` |
| PR title check | Enforces Conventional Commits on PR titles | PR opened/edited | `.github/workflows/pr-title.yml` |
| DCO app | Checks every commit has `Signed-off-by` | PR push | GitHub App (probot/dco) |
| Labeler | Adds area labels from changed paths (`area/policy`, `area/hub`, …) | PR opened | `.github/labeler.yml` |
| Issue forms + triage label | Structured bug and feature reports; new issues get `needs-triage` | Issue opened | `.github/ISSUE_TEMPLATE/*.yml` |
| Welcome bot | Thanks first-time issue authors and contributors, links CONTRIBUTING | First issue / PR | `.github/workflows/welcome.yml` |
| Stale | Marks `needs-info` issues stale after 14 days, closes after 7 more; never touches `accepted` or `security` | Daily | `.github/workflows/stale.yml` |
| Lock closed | Locks old closed issues so new problems become new issues | Weekly | workflow |
| CodeQL | Static analysis for TypeScript and Python | PR, push, weekly | `.github/workflows/codeql.yml` |
| OpenSSF Scorecard | Scores repository security practices; badge in README | Weekly + push | `.github/workflows/scorecard.yml` |
| Dependency review | Blocks PRs adding vulnerable or disallowed-licence dependencies | PR | in `ci.yml` |
| Codecov | Coverage reports and patch gates | CI upload | `codecov.yml` |
| All Contributors | Credits every kind of contribution in README | Comment command | `.all-contributorsrc` |
| Docs deploy | Builds Starlight docs and deploys to GitHub Pages | Release + docs changes | `.github/workflows/docs.yml` |

> **Why Release Please and not Changesets**
>
> - Release Please supports **both npm and Python packages** in one monorepo manifest; Changesets is JavaScript-only.
> - Versions come from **commit history** that is already enforced (Conventional Commits), so contributors do not need to add changeset files.
> - The release PR is a natural **human approval point** before anything is published.

# 10. Dependency Management

| Rule | Detail |
| --- | --- |
| Fewer is safer | Each runtime dependency is attack surface for every AgentKeel user. The policy engine (L1) has at most 3 runtime dependencies (`yaml`, a glob matcher, the CEL evaluator). |
| Licence allowlist | MIT, Apache-2.0, BSD-2/3-Clause, ISC, 0BSD, BlueOak, Python-2.0. Copyleft (GPL, AGPL) blocked in runtime dependencies by dependency review. |
| Update cadence | Dependabot weekly, grouped by ecosystem (one PR for dev dependencies, one for runtime minor/patch, majors separate). |
| Auto-merge | Patch updates of dev dependencies and GitHub Actions auto-merge after green CI. Runtime and major updates need human review. |
| Security updates | Dependabot security PRs are triaged within 48 hours; critical ones release within 7 days. |
| Lockfiles | Committed; CI fails if they are out of date. Published packages use ranges for users, lockfiles only for our CI. |
| Node and Python support | Support all LTS Node lines (22, 24) and all non-EOL Python versions (3.11+). Dropping a version is a minor release with a notice one release earlier. |

# 11. Release Management

System flow 3 shows the release pipeline. Releases are boring on purpose: automated, repeatable and approved by a person.

## 11.1 Versioning

| Topic | Policy |
| --- | --- |
| Scheme | Semantic Versioning 2.0. Before 1.0: `0.MINOR.PATCH`, breaking changes bump MINOR. From 1.0: strict semver. |
| Per package | Each npm package and the Python package has its own version; Release Please links versions that must move together (`sdk`, `hub`, `cli`, `spec`). |
| Stable contracts | Policy language `version: 1` and Event Schema `1.x` have their own versions and stability rules (Event Schema Spec §9). |
| Channels | npm dist-tags: `latest` (stable), `next` (release candidates). PyPI: pre-release versions (`0.2.0rc1`). |
| Cadence | Minor at the end of a cycle when features land; patch any time a fix merges. |
| Support window | Latest minor gets all fixes; previous minor gets security fixes for 3 months (after 1.0: 6 months). |
| Deprecation | Deprecated APIs warn at runtime and in docs for at least one minor release before removal; removal only in a breaking release. |

## 11.2 Release checklist (automated where possible)

- **1.** Release PR reviewed: versions, changelog wording, breaking-change notes and migration steps.
- **2.** PRD §19 release criteria ticked in the release issue (design partners, docs, quick start on 3 OS).
- **3.** Merge release PR → tags and GitHub Releases created.
- **4.** `release` environment (requires maintainer approval) publishes to npm with provenance and to PyPI with Trusted Publishing and attestations.
- **5.** SBOM (CycloneDX) and checksums attached to the GitHub Release.
- **6.** Post-publish verification installs from the registries on Linux, macOS and Windows and runs the quick start.
- **7.** Docs deployed; README GIF refreshed for minor releases; announcement posted in Discussions and social channels.

## 11.3 Rollback

Registries do not allow overwriting a version. If a release is broken: deprecate it on npm (`npm deprecate`) and yank it on PyPI, fix forward with a patch release, and post a notice in the GitHub Release and Discussions. A broken release is followed by a short blameless post-mortem in `docs/postmortems/`.

# 12. Supply-Chain Security

Supply-chain attacks on open-source packages are now one of the most common ways attackers reach companies. AgentKeel users trust it with agent actions, so the project aims for the strongest practices available for free.

| Control | Implementation | Target |
| --- | --- | --- |
| Account security | 2FA required for all org members; npm and PyPI accounts with 2FA; no shared accounts. | Day 1 |
| Branch and tag protection | Rulesets on `main` and `v*` tags: PR, review, checks, no force push, signed release tags by the bot. | Day 1 |
| Token-less publishing | npm trusted publishing and PyPI Trusted Publishing via GitHub OIDC; no long-lived registry tokens stored anywhere. | v0.1 |
| Build provenance | npm `--provenance`; PyPI attestations; GitHub artifact attestations for release archives. | v0.1 (npm), v0.2 (all) |
| SLSA | Builds on GitHub-hosted runners from a protected workflow with provenance. | Build L2 at v0.2, L3 by v1.0 |
| SBOM | CycloneDX SBOM generated per release and attached. | v0.2 |
| Pinned actions | All actions pinned by SHA; Dependabot updates. | Day 1 |
| Secret protection | GitHub secret scanning + push protection; gitleaks in CI. | Day 1 |
| Static analysis | CodeQL on every PR; Semgrep rules for custom patterns (e.g. no `eval`, no logging of raw args). | v0.1 |
| Scorecard | OpenSSF Scorecard weekly with README badge. | ≥ 7.5 at v0.1, ≥ 8.5 at v1.0 |
| Best Practices badge | OpenSSF Best Practices "passing". | v0.2; "silver" by v1.0 |

# 13. Security Process

System flow 4 shows vulnerability handling. Details for reporters live in `SECURITY.md`.

| Area | Practice |
| --- | --- |
| Reporting | GitHub **private vulnerability reporting** is enabled, so reporters need no email address and no domain is required. Public issues for vulnerabilities are redirected. |
| Response times | Acknowledge within 48 hours; triage within 5 days; fix critical within 14 days and high within 30 days; medium and low in the next release. |
| Scoring | CVSS 4.0 with a short written impact statement specific to agents (what an attacker could make an agent do). |
| Fixing | In the advisory's temporary private fork, with tests; reviewed by a second maintainer when available. |
| Disclosure | GitHub Security Advisory published with patched versions; CVE requested through GitHub; reporter credited unless they ask otherwise. |
| Threat modelling | Every L1/L2 feature PR includes a short STRIDE note. A full threat model lives in the TDD and is reviewed each minor release. |
| Security review | Before 1.0: an external review (volunteer, OpenSSF programme or sponsor). Findings tracked as advisories or issues. |

# 14. Documentation Workflow

| Artefact | Where | Rule |
| --- | --- | --- |
| Docs site | `docs/` (Astro Starlight) → agentkeel.github.io | Updated in the same PR as the feature; versioned per minor from v1.0. |
| README | Repository root | Animated logo, 3-command quick start, GIF of a blocked action, loop diagram, badges (CI, npm, PyPI, downloads, licence, Scorecard, Best Practices). Reviewed every minor release. |
| API reference | Generated (TypeDoc, pdoc) into the docs site | Built on release; TSDoc required on exports. |
| ADRs | `adr/NNNN-title.md` (MADR) | One per significant decision; superseded, never deleted. |
| RFCs | `rfcs/` after acceptance | For public API, policy language and event schema changes. |
| Changelog | `CHANGELOG.md` per package | Generated by Release Please from PR titles; human-written highlights at the top of GitHub Releases. |
| Examples | `examples/` | Each example runs in CI; README in each folder. |
| Diagrams | Source in repo, rendered PNG/SVG | System-flow style (as in these documents) for consistency. |

# 15. Community Operations

| Practice | How |
| --- | --- |
| Triage | Daily 15-minute triage by the maintainer (rotation once there are 3+ maintainers). Goal: no issue without a label after 72 hours. |
| Labels | Type, area, priority, size, status and community labels (Appendix 22.1). Consistent labels make search and good-first-issues work. |
| Good first issues | At least 10 open `good first issue` items at any time, each with context, file pointers and expected test. |
| Discussions | Categories: Announcements, Q&A, Ideas, Show and tell, Policy packs. Questions go here, bugs go to issues. |
| Recognition | All Contributors table in README; release notes thank contributors by handle; "contributor of the month" in Discussions. |
| Path to maintainer | Defined in GOVERNANCE.md: sustained quality contributions over 3 months, nominated and approved by existing maintainers. |
| Code of Conduct | Contributor Covenant 2.1; reports to the conduct contact listed in the file; enforcement by maintainers. |
| Communication | Public by default: decisions in issues, Discussions, ADRs. Private only for security and conduct cases. |

# 16. AI-Assisted Development Policy

AgentKeel will be built largely with Claude Code. That is a strength if it is done openly and safely, and a risk if generated code is merged without understanding. These rules apply to maintainers and contributors.

| Rule | Why |
| --- | --- |
| A human author is responsible for every line, whoever or whatever typed it. | Accountability and DCO sign-off require it. |
| AI-generated code passes exactly the same review, tests and rigor level as any code. | Quality bar does not depend on the tool. |
| Never paste secrets, private user data or unreleased security details into AI tools. | Prevents leaks through prompts. |
| `CLAUDE.md` in the repo gives the AI the architecture rules, commands and do-nots. | Consistent, rule-following output. |
| Claude Code on this repo runs behind AgentKeel itself (coding-agent pack). | Dogfooding: blocks force pushes, `.env` reads, edits to `agentkeel.yaml` and destructive commands. |
| PR descriptions mention significant AI assistance in one line. | Transparency for reviewers. |

# 17. Environments, Infrastructure and Cost

The whole SDLC runs on free tiers available to public repositories. No domain and no paid service are required for v0.1 to v1.0.

| Need | Service | Cost |
| --- | --- | --- |
| Code hosting, issues, Discussions, Projects | GitHub Free (organisation `agentkeel`) | Free |
| CI/CD incl. macOS and Windows runners | GitHub Actions (free for public repositories) | Free |
| Docs website | GitHub Pages: agentkeel.github.io | Free |
| Package registries | npm (`@agentkeel` org, `agentkeel`), PyPI (`agentkeel`) | Free |
| Coverage | Codecov free for open source | Free |
| Security scanning | CodeQL, secret scanning, Dependabot, Scorecard | Free |
| Release environment | GitHub Environment `release` with required reviewer | Free |
| Container image (v1.0 server mode) | GitHub Container Registry (`ghcr.io/agentkeel/hub`) | Free for public images |

# 18. Metrics and Health

| Metric | Target | Source |
| --- | --- | --- |
| Deployment frequency (DORA) | At least one release per 2-week cycle | GitHub Releases |
| Lead time for changes (DORA) | Median < 3 days from PR open to release | PR and release timestamps |
| Change failure rate (DORA) | < 10 % of releases need a hotfix | Patch releases tagged hotfix |
| Time to restore (DORA) | Broken release fixed < 24 h | Issue timestamps |
| Time to first response | < 72 h for issues and PRs (median < 24 h) | GitHub insights / CHAOSS |
| PR merge time | Median < 5 days for external PRs | GitHub insights |
| CI duration | p50 < 10 min | Actions metrics |
| Flaky test rate | < 1 % of runs | CI reruns |
| OpenSSF Scorecard | ≥ 7.5 (v0.1) → ≥ 8.5 (v1.0) | Scorecard badge |
| Contributor growth | 40 contributors at 12 months (BRD KPI) | GitHub contributors |

# 19. GitHub Settings Checklist

These are the exact settings to apply in the `agentkeel` organisation and repository. They can be clicked in the UI once; the list doubles as an audit checklist.

| Where | Setting |
| --- | --- |
| Org → Authentication security | Require two-factor authentication for everyone. |
| Org → Member privileges | Base permission: Read. Members cannot create public repositories or change visibility. |
| Org → Actions | Allow GitHub, verified creators and listed actions only; require approval for first-time fork contributors. |
| Repo → General | Allow squash merge only; default commit message = PR title; auto-delete head branches; Discussions on; Wiki off. |
| Repo → Rules → Rulesets (`main`) | Require PR, 1 approval, dismiss stale approvals, CODEOWNERS review, `ci-ok` status, merge queue, linear history, block force push and deletion. |
| Repo → Rules → Rulesets (tags `v*`) | Only the release workflow may create; no deletion or update. |
| Repo → Code security | Dependency graph, Dependabot alerts and security updates, secret scanning, push protection, private vulnerability reporting, CodeQL default setup off (advanced workflow used). |
| Repo → Environments | `release`: required reviewer = maintainers; deployment branches = `main` and tags only. |
| Repo → Pages | Source: GitHub Actions (docs workflow). |
| npm → @agentkeel org | 2FA required; trusted publisher configured for `agentkeel/agentkeel` release workflow. |
| PyPI → agentkeel | Trusted publisher configured for the release workflow and `release` environment; delete any API tokens. |

# 20. Setup Rollout Plan

The full SDLC is set up before feature work starts, so the first line of product code already lands through the final process.

| When | What gets set up | Done when |
| --- | --- | --- |
| Week 1 (Dec 2026) | Community files, issue forms, PR template, CODEOWNERS, labels, rulesets, 2FA, security settings | Repository passes the Section 19 checklist |
| Week 1 | Monorepo skeleton (pnpm, Turborepo, Biome, tsconfig, Vitest), lefthook, commitlint | `pnpm i && pnpm test` green on 3 OS |
| Week 2 | CI workflow with `ci-ok`, CodeQL, Scorecard, dependency review, Dependabot, labeler, stale, welcome | First PR merged through the merge queue |
| Week 2 | Release Please, release workflow with trusted publishing (dry run to `next`) | `0.0.2-next` published with provenance |
| Week 3 | Docs site skeleton on GitHub Pages; ADR template; first ADRs (0001–0005) | Docs live at agentkeel.github.io |
| Week 3 | Benchmark harness and conformance vector format | Bench job compares against `main` |
| From week 4 | Feature work in PRD order (F-03 first) | Each feature meets the Definition of Done |

# 21. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Maintainer burnout (solo project) | Slow responses, abandoned project | Bots for routine work; cool-down weeks; WIP limit 2; clear "not now" labels; recruit maintainers early via GOVERNANCE.md. |
| CI becomes slow | Contributors wait, PRs pile up | 10-minute budget; caching; affected-only runs; nightly for the heavy matrix. |
| Compromised dependency or action | Malicious code shipped to users | Pinned SHAs, few dependencies, dependency review, harden-runner, provenance, SBOM. |
| Leaked registry credentials | Attacker publishes a fake version | No long-lived tokens (OIDC trusted publishing); 2FA everywhere; release environment approval. |
| Low-quality AI-generated PRs | Review overload, hidden bugs | Same bar for all code; small PRs; tests required; maintainers may close PRs without explanation beyond the template checklist. |
| Breaking users by accident | Loss of trust | API Extractor diff, schema contract tests, RFC process, deprecation window, conformance suite. |
| Toxic interactions | Contributors leave | Code of Conduct, quick moderation, locking heated threads, kind templates. |

# 22. Appendix

## 22.1 Label taxonomy

| Group | Labels |
| --- | --- |
| Type | `type/bug`, `type/feature`, `type/docs`, `type/chore`, `type/security`, `type/rfc` |
| Area | `area/policy`, `area/core`, `area/sdk`, `area/hub`, `area/cli`, `area/dashboard`, `area/mcp`, `area/notifiers`, `area/spec`, `area/python`, `area/packs`, `area/docs`, `area/ci` |
| Priority | `priority/critical`, `priority/high`, `priority/medium`, `priority/low` |
| Size | `size/S` (< 1 day), `size/M` (1–3 days), `size/L` (needs shaping) |
| Status | `needs-triage`, `needs-info`, `accepted`, `blocked`, `wontfix`, `duplicate`, `stale` |
| Community | `good first issue`, `help wanted`, `design-partner` |
| Release | `breaking-change`, `autorelease: pending`, `autorelease: tagged` (bot) |

## 22.2 Glossary

| Term | Meaning |
| --- | --- |
| DCO | Developer Certificate of Origin: contributors certify they have the right to submit code by signing off commits. |
| Merge queue | GitHub feature that re-tests approved PRs on the latest `main` before merging, one group at a time. |
| OIDC trusted publishing | Registries accept short-lived identity tokens from a specific GitHub workflow instead of stored passwords. |
| Provenance / attestation | Signed statement of which source and workflow built a package, verifiable by users. |
| SLSA | Framework of levels for supply-chain integrity of builds. |
| SBOM | Software Bill of Materials: list of all components in a release. |
| DORA metrics | Four delivery metrics: deployment frequency, lead time, change failure rate, time to restore. |
| Mutation testing | Deliberately injecting bugs to check whether tests catch them. |

## 22.3 Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Lead maintainer | Ashutosh Kumar Rao | Pending review |  |
