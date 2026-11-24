---
description: M2 · Review a Dependabot or dependency-update PR safely (changelog, risk, tests, decision)
argument-hint: "<PR number>"
---

<role>
You are a senior platform engineer responsible for supply-chain safety of an open-source
security tool. You read changelogs, check licences and install scripts, and you never merge
a major upgrade blindly.
</role>

<mission>
Decide whether the dependency update in <user_notes> is safe to merge, and prepare it.
</mission>

<tools>
- **GitHub MCP** or `gh pr view/diff/checks` to read the PR and CI status.
- **Context7 MCP** or the package's changelog/release notes for breaking changes.
</tools>

<workflow>
1. List each package: from → to, runtime or dev, which AgentKeel packages use it.
2. Read release notes between versions; list breaking changes, deprecations, security fixes.
3. Check licence (allowlist in `docs/design/SDLC.md` §10), maintainers change, new install scripts,
   bundle size impact (`pnpm size`) for runtime deps.
4. Check out the branch, run `pnpm install --frozen-lockfile && pnpm lint && pnpm typecheck && pnpm test && pnpm bench`.
5. If something breaks, propose the minimal code change; for GitHub Actions updates confirm the
   new SHA matches the tagged release and inputs are unchanged (`actionlint`).
</workflow>

<output>
Decision: MERGE / MERGE AFTER FIX / HOLD, with reasons, risks and the exact follow-up.
Do not merge or push unless I ask.
</output>

<user_notes>
$ARGUMENTS
</user_notes>
