# Contributing to AgentKeel

Thank you for helping make AI agents safer. Every kind of contribution counts:
bug reports, docs, policy packs, plugins, tests, reviews and code.

> **New here?** Look for issues labelled
> [`good first issue`](https://github.com/agentkeel/agentkeel/labels/good%20first%20issue).
> Comment on the issue so we can help you get started. We reply within 72 hours.

## Ground rules

- Be kind. This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
- Security problems are **never** reported in public issues. See [SECURITY.md](SECURITY.md).
- Questions go to [Discussions](https://github.com/agentkeel/agentkeel/discussions); bugs and accepted ideas go to issues.
- Changes to the public API, the policy language or the event schema need an
  RFC issue first (template: "RFC"), open for comments for at least 7 days.

## Development setup

Requirements: Node.js 22 or 24, pnpm (via `corepack enable`), Python 3.11+ and
[uv](https://docs.astral.sh/uv/) for the Python SDK, Git.

```bash
git clone https://github.com/<your-fork>/agentkeel.git
cd agentkeel
corepack enable
pnpm install
pnpm test          # all TypeScript tests
pnpm dev           # watch mode
cd python/agentkeel && uv sync && uv run pytest   # Python SDK
```

## Making a change

1. **Find or open an issue** and say you are working on it.
2. **Branch** from `main`: `feat/policy-matches-operator`, `fix/mcp-denial-result`, `docs/quick-start`.
3. **Keep the PR small** (ideally under 400 changed lines). Split big work behind a flag.
4. **Write tests** at the level the package needs (see "Rigor levels" below).
5. **Update docs** in `docs/` and examples if behaviour changes.
6. **Sign off every commit** (Developer Certificate of Origin):
   ```bash
   git commit -s -m "feat(policy): add matches operator"
   ```
   This adds `Signed-off-by: Your Name <email>` and certifies the
   [DCO](https://developercertificate.org/). Forgot? `git commit --amend -s` or
   `git rebase --signoff main`.
7. **Open the PR** with a title in [Conventional Commits](https://www.conventionalcommits.org/) form.
   The title becomes the squash commit and drives the changelog and version.

### PR title format

```
<type>(<scope>)!: <summary in imperative mood>
```

| type | releases as | use for |
|------|-------------|---------|
| `feat` | minor | new user-facing capability |
| `fix` | patch | bug fix |
| `perf` | patch | faster, same behaviour |
| `deps` | patch | dependency updates |
| `docs`, `test`, `refactor`, `build`, `ci`, `chore` | none | everything else |
| `!` after scope | breaking | add `BREAKING CHANGE:` notes in the PR body |

Scopes: `policy`, `core`, `sdk`, `hub`, `cli`, `dashboard`, `mcp`, `notifiers`,
`spec`, `python`, `packs`, `docs`, `ci`.

## Rigor levels

| Level | Packages | Minimum |
|-------|----------|---------|
| L1 critical | `policy`, `core`, redaction, hash chain, approvals | 95% coverage, property tests, benchmark, ADR for behaviour changes |
| L2 important | `sdk`, `hub`, `mcp-proxy`, stores, notifiers, Python SDK | 85% coverage, contract tests |
| L3 standard | `cli`, `dashboard`, adapters, `testkit` | 75% coverage, e2e happy path |
| L4 light | docs, examples, scripts | builds and runs in CI |

## Review and merge

- CODEOWNERS are requested automatically. Expect a first review within 72 hours.
- Reviewers check, in order: safety, API shape, tests, performance, docs.
- When approved and green, the PR enters the **merge queue**, is re-tested on the
  latest `main` and squash-merged.

## Using AI assistants

AI tools (Claude Code, Copilot, etc.) are welcome. You remain responsible for
every line: understand it, test it, and sign off. Never paste secrets or private
data into AI tools. Mention significant AI assistance in one line of the PR body.

## Other ways to contribute

- **Policy packs** in `packs/` (rules + tests + docs).
- **Plugins**: notifiers, detectors, exporters, adapters (see docs "Plugins").
- **Red-team cases** for the test suite.
- **Docs and examples**, translations, and answering Discussions.

All contributors are credited in the README via All Contributors.
