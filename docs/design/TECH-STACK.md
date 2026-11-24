# AgentKeel Tech Stack v1.0

> Markdown copy of the Word document for use by contributors and Claude Code. The Word/PDF version is the formatted original; diagrams are in `flows/`.

# 1. Overview

This document lists every technology in AgentKeel, the job it does, and why it beat the alternatives. It also explains the **engineering techniques** used at the high-level design (HLD) and low-level design (LLD) levels, so a contributor understands not only *what* the code uses but *which proven patterns* hold it together. Details of how each part is built live in the TDD; this is the map.

## 1.1 Selection criteria

| Criterion | Meaning |
| --- | --- |
| Safety and maturity | Widely used in production, actively maintained, good security record. Safety is the product. |
| Small footprint | AgentKeel runs inside users' agent processes; every dependency is their risk and their install time. |
| Zero cost | Free and open source, free tiers for public repositories; nothing that forces users to pay. |
| Licence compatibility | Permissive licences only in runtime dependencies (MIT, Apache-2.0, BSD, ISC). |
| Contributor familiarity | Mainstream tools so first-time contributors can help in a weekend. |
| Portability | Linux, macOS and Windows; Node and Bun; Python. |

# 2. Stack at a Glance

| Layer | Choice |
| --- | --- |
| Language | TypeScript (strict) for everything except the Python SDK |
| Runtime | Node.js 22 and 24 LTS; Bun compatible; Python 3.11+ |
| Monorepo | pnpm workspaces + Turborepo; tsup for builds; Biome for lint/format |
| Policy engine | `yaml`, Ajv (JSON Schema), picomatch (globs), CEL subset evaluator |
| Contracts | Zod schemas → OpenAPI 3.1; JSON Schema 2020-12 for events; CloudEvents envelope |
| Keel Hub | Hono on Node, SSE, pino logs, Prometheus metrics |
| Storage | SQLite (better-sqlite3, WAL) locally; Postgres (node-postgres) in server mode; Drizzle ORM |
| Integrations | MCP TypeScript SDK; Slack Bolt (Socket Mode); grammY (Telegram); Nodemailer |
| Dashboard | Vite, React, TanStack Router + Query + Virtual, Tailwind CSS, shadcn/ui (Radix) |
| Python SDK | uv, hatchling, httpx, Pydantic v2, Ruff, Pyright, pytest, Hypothesis |
| Testing | Vitest, fast-check, StrykerJS, Playwright, Schemathesis, Testcontainers, mitata, k6, Jazzer.js |
| Docs | Astro Starlight on GitHub Pages; TypeDoc; pdoc |
| CI/CD and security | GitHub Actions, Release Please, Dependabot, CodeQL, OpenSSF Scorecard, harden-runner, gitleaks, dependency review, CycloneDX SBOM, npm provenance, PyPI Trusted Publishing |

# 3. Language and Runtime

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| TypeScript (strict) | All packages except Python SDK | Agent ecosystem (MCP SDK, Claude Code, Vercel AI SDK, OpenAI Agents SDK) is strongest in TS; one language for SDK, Hub, CLI and dashboard; types shared across all of them. |
| Node.js 22 / 24 LTS | Runtime for SDK, Hub, CLI, proxy | Long-term support lines; built-in `crypto` (SHA-256, Ed25519), `worker_threads`, `fs.watch`, native test of UDS and named pipes. Node 20 reached end of life in April 2026 and is not supported. |
| Bun (compatibility target) | Users who run agents on Bun | SDK avoids Node-only APIs on the hot path; CI runs SDK tests on Bun. |
| Python 3.11+ | Python SDK (v0.2) | Large share of agent code (LangGraph, CrewAI, OpenAI Agents SDK) is Python; 3.10 reached end of life in October 2026. |

> **Why not Rust or Go for the core?**
>
> - Rust would give a single fast engine for every language via WASM or FFI, but it slows contributions, complicates builds on 3 OS and is unnecessary: the TypeScript engine already meets the 2 ms p95 budget with an index-based design.
> - Go would suit the Hub, but splitting languages between SDK and Hub doubles the types, tests and contributor skills needed. Revisit only if profiling proves a real bottleneck (ADR required).

# 4. Monorepo and Build Tooling

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| pnpm workspaces | Package manager and workspace linking | Fast, disk-efficient, strict (no phantom dependencies), first-class workspaces and `--frozen-lockfile`. |
| Turborepo | Task runner with caching | Runs only affected tasks, caches builds and tests locally and in CI; simple config. |
| tsup (esbuild) | Bundles each package to ESM + CJS + `.d.ts` | Very fast builds, tree-shaking, small output; good for libraries with dual formats. |
| Biome | Lint and format for TS/JS/JSON | One fast tool instead of ESLint + Prettier; consistent across editors and CI. |
| lefthook | Git hooks (format, lint staged files, commit message) | Fast, language-agnostic, no Node dependency at hook time. |
| commitlint | Conventional Commits checks | Feeds Release Please; keeps history meaningful. |
| API Extractor | Public API reports for SDK packages | Fails CI on accidental public API changes (NFR-17). |
| dependency-cruiser | Architecture rules | Enforces hexagonal layering (core may not import adapters). |
| Knip, size-limit | Unused code/dependencies; bundle budgets | Keeps the SDK small (NFR-13). |

# 5. Core Libraries

The policy engine and core are rigor level L1. Their runtime dependencies are deliberately few and each one is small, popular and audited.

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| `yaml` | Parse `agentkeel.yaml` with line and column positions | Spec-compliant YAML 1.2, no native code, precise error locations for helpful messages. |
| Ajv | Validate policy files and events against JSON Schema 2020-12 | Fastest JS validator; compiles schemas to functions; standard JSON Schema support. |
| Zod | Runtime validation of API requests and SDK options; source for OpenAPI | TypeScript-first; one schema gives types, validation and OpenAPI. |
| picomatch | Tool-name globs (`db.*`) | Small, fast, no dependencies; used by major tooling. |
| CEL subset evaluator | `when:` expressions (v0.2) | Common Expression Language is safe (no loops, no side effects) and used in Kubernetes and Google Cloud policies. Existing JS implementation vs minimal own evaluator decided by spike (TDD TQ1). |
| `node:crypto` | SHA-256 hash chain, HMAC redaction markers, Ed25519 checkpoints | Built into Node; no third-party crypto. |
| `canonicalize` | RFC 8785 JSON Canonicalization (JCS) | Tiny reference implementation; makes hashes stable across languages. |
| `typeid-js` (or ~40 lines in-house) | TypeID identifiers over UUIDv7 | Readable, typed, time-sortable IDs (ADR-0008). |

# 6. Keel Hub and Storage

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| Hono | HTTP framework for API v1 | Small, very fast, Web-standard Request/Response, runs on Node and Bun, excellent TypeScript types and Zod/OpenAPI middleware (ADR-0015). |
| `@hono/node-server` | Serve Hono over TCP, Unix sockets and named pipes | Lets the same app listen on UDS (SDK) and 127.0.0.1 (dashboard). |
| Server-Sent Events | Streams for dashboard, `tail`, control snapshots | One-way, works through proxies, auto-reconnect with `Last-Event-ID`; simpler than WebSockets. |
| better-sqlite3 | Local store driver | Synchronous, very fast, mature, prebuilt binaries for all platforms; ideal for a single-writer daemon. |
| SQLite (WAL, STRICT tables) | Default database | Zero-config, one file, proven reliability; WAL allows concurrent reads during writes (ADR-0003). |
| node-postgres (`pg`) | Server-mode driver | Most used Postgres driver; supports `LISTEN/NOTIFY`, pooling, COPY. |
| PostgreSQL | Server-mode database | Partitioning, RLS, `SKIP LOCKED`, advisory locks, JSONB: everything server mode needs without extra infrastructure. |
| Drizzle ORM + drizzle-kit | Typed queries and migrations for both engines | Thin SQL-like ORM, no heavy runtime or engine binary; supports SQLite and Postgres; raw SQL where needed. |
| pino | Structured logging | Fastest Node logger; redaction support; JSON output. |
| prom-client | Prometheus metrics | Standard metrics format for self-hosted monitoring. |

# 7. Integrations

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| `@modelcontextprotocol/sdk` | MCP types, transports, reference behaviour for the proxy | Official TypeScript SDK of the protocol; keeps the proxy compatible as MCP evolves. |
| Slack Bolt for JS (Socket Mode) | Slack approvals | Official SDK; Socket Mode uses an outbound WebSocket, so no public URL or domain is needed. |
| grammY | Telegram approvals | Modern, well-typed Telegram Bot API framework; long-polling works without a webhook URL. |
| Nodemailer | Email approvals (v0.2) | De-facto standard for SMTP in Node. |
| Claude Code hooks | Coding-agent integration | Documented hook events (PreToolUse, PostToolUse) with JSON in/out; no patching of Claude Code. |
| OpenAI Agents SDK, LangGraph, CrewAI, Vercel AI SDK | Framework adapters (v0.2–v0.3) | The most used agent frameworks across TS and Python; thin adapters over `guard()`. |
| OpenTelemetry JS (OTLP exporter) | Export to observability backends (v0.3) | Vendor-neutral standard; GenAI semantic conventions for agent spans. |

# 8. Dashboard

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| Vite | Dev server and production build | Instant dev server, small optimised bundles; static output the Hub can serve (ADR-0016). |
| React | UI library | Largest contributor pool; mature accessibility and component ecosystem. |
| TanStack Router | Type-safe client routing with URL search params | Filters live in the URL (shareable links) with full typing. |
| TanStack Query | Server state, caching, revalidation | Handles loading, retries, ETags and SSE-driven invalidation cleanly. |
| TanStack Virtual | Virtualised feeds and traces | Smooth scrolling over thousands of rows. |
| Tailwind CSS | Styling with design tokens | Consistent spacing and colour from the AgentKeel brand; no runtime CSS-in-JS cost. |
| shadcn/ui on Radix primitives | Accessible components (dialogs, menus, tables) | Copy-in components we own; Radix handles keyboard and screen-reader behaviour (WCAG 2.1 AA). |
| Recharts | Small charts on Home and Tests screens | Simple, React-native charts; enough for counts and trends. |
| Self-hosted Inter and JetBrains Mono | Typography | No network calls from the dashboard (privacy, offline). |

> **Why not Next.js for the dashboard?**
>
> - The dashboard is served by the Hub on localhost and needs no server rendering, SEO or edge functions.
> - A static SPA is smaller, starts instantly, works offline and adds no second server process. (QueueOS, a hosted SaaS, rightly uses Next.js.)

# 9. Python SDK

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| uv | Environment, dependency and lockfile management | Very fast resolver and installer; one tool for venvs, locking and running. |
| hatchling | Build backend | Standards-based (PEP 517/621), simple config. |
| httpx | HTTP client to the Hub (sync and async, Unix sockets) | Modern API, HTTP/1.1 and HTTP/2, UDS transport support. |
| Pydantic v2 | Typed models generated from the event JSON Schemas | Fast validation; models generated so TS and Python cannot drift. |
| datamodel-code-generator | Generate Pydantic models from JSON Schema | One schema source of truth (`@agentkeel/spec`). |
| Ruff | Lint and format | Extremely fast; replaces flake8, isort and black. |
| Pyright (strict) | Type checking | Catches errors early; ships `py.typed` for users. |
| pytest + Hypothesis | Unit and property tests | Standard testing plus the same invariants as fast-check. |

# 10. Testing Tools

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| Vitest | Unit and integration tests for all TS packages | Fast, Jest-compatible API, native ESM and TypeScript, workspace support. |
| fast-check | Property-based tests of the policy engine | Finds edge cases humans miss; proves invariants like order independence. |
| StrykerJS | Mutation testing of L1 packages | Measures whether tests would catch real bugs, not just line coverage. |
| Playwright | Dashboard end-to-end and accessibility (axe) tests | Reliable cross-browser automation; also used for screenshots and README GIFs. |
| Schemathesis | Property-based API tests from the OpenAPI document | Generates thousands of requests to find contract and error-handling bugs. |
| Testcontainers | Real Postgres in integration tests | Tests the server-mode adapter against the real database. |
| mitata / tinybench | Micro-benchmarks of decision and ingest paths | Stable numbers for CI regression gates (NFR-01/02). |
| k6 | Load tests for the Hub API | Scriptable load generation for capacity planning. |
| Jazzer.js | Fuzzing the YAML/policy parser and MCP framing | Coverage-guided fuzzing finds crashes in parsers. |
| Codecov | Coverage reporting and patch gates | Free for open source; PR comments. |

# 11. Docs and Website

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| Astro Starlight | Documentation site | Purpose-built for docs: search, sidebar, i18n, dark mode, fast static output. |
| GitHub Pages | Hosting at agentkeel.github.io | Free, no domain needed, deploy from Actions. |
| TypeDoc, pdoc | API reference for TS and Python | Generated from code comments; never out of date. |
| Graphviz + Playwright | System-flow diagrams (as in these documents) | Diagrams as code, rendered in CI, consistent style. |
| MADR | ADR template | Lightweight, widely used decision record format. |

# 12. CI/CD and Security Tooling

| Technology | Role in AgentKeel | Why this one |
| --- | --- | --- |
| GitHub Actions | CI, releases, docs deploy, bots | Free for public repositories, including macOS and Windows runners. |
| Merge queue | Re-test approved PRs on latest `main` | Keeps `main` always green. |
| Release Please | Versions, changelogs, tags for npm and Python packages | Works for multi-language monorepos from Conventional Commits. |
| Dependabot | Dependency and Actions updates, security PRs | Native to GitHub; grouped updates. |
| CodeQL | Static application security testing (TS, Python) | Free for public repos; deep data-flow analysis. |
| Dependency review action | Blocks vulnerable or disallowed-licence dependencies in PRs | Enforces licence allowlist automatically. |
| gitleaks + GitHub secret scanning | Secret detection with push protection | Stops tokens before they reach history. |
| OpenSSF Scorecard | Repository security score and badge | Industry-standard checklist of supply-chain practices. |
| step-security/harden-runner | Audit network egress of CI jobs | Detects compromised build steps. |
| npm trusted publishing + provenance | Token-less npm releases with signed provenance | No long-lived tokens; users can verify builds. |
| PyPI Trusted Publishing + attestations | Token-less PyPI releases | Same guarantees for Python. |
| CycloneDX (via anchore/sbom-action) | SBOM per release | Standard component inventory for users' compliance. |
| GitHub Container Registry | `ghcr.io/agentkeel/hub` image (v1.0) | Free for public images; same identity as the repository. |

# 13. HLD Techniques

High-level design techniques shape the whole system. Each is a well-known industry pattern, applied for a specific reason.

| Technique | Where it is used | Problem it solves |
| --- | --- | --- |
| C4 model | Flows 1, 2 and 10 (context, containers, deployment) | Shared language for explaining architecture at the right zoom level. |
| Hexagonal architecture (ports and adapters) | `policy` and `core` packages; stores, notifiers, transports as adapters | Pure, testable core reused in SDK and Hub; swappable infrastructure. |
| Modular monolith | Keel Hub modules in one process | Simplicity of one deployable with clear internal boundaries. |
| Embedded engine + local daemon (sidecar) | SDK evaluates; Hub owns shared state | Microsecond decisions plus cross-process kill switches, budgets and approvals. |
| Event sourcing (light) + CQRS (light) | Events are truth; projections for reads | Full audit and replay; fast dashboard queries. |
| Single-writer principle | Hub writes the store and chain | Correct ordering and hash chain without distributed coordination. |
| Stateless replicas + shared database | Server mode | Horizontal scaling by adding Hub replicas. |
| Fail-safe defaults | `on_error`, `on_timeout`, stale control | Safety over availability for a security product. |
| Local-first, privacy by design | Default deployment, redaction, opt-in telemetry | Trust; compliance with data-protection laws such as DPDP. |
| API-first, contract-first | Zod → OpenAPI, JSON Schema → models | SDKs, CLI and dashboard all built on one public contract. |
| Architecture Decision Records | `adr/` folder | Decisions and trade-offs stay visible to contributors. |

# 14. LLD Techniques

Low-level design techniques solve specific problems inside components. The TDD section for each is given in brackets.

| Technique | Where it is used | Problem it solves |
| --- | --- | --- |
| Indexed rule matching + LRU cache | Policy engine (§7) | Evaluate only candidate rules for a tool; O(k) instead of O(n). |
| Most-restrictive-wins fold | Policy engine (§7) | Rule order can never weaken safety. |
| Copy-on-write hot reload | Policy reload (§7.4) | Atomic policy swap without locks; in-flight decisions unaffected. |
| Property-based testing of invariants | Engine, redaction (§7.3) | Proves rules hold for thousands of random cases. |
| Ring buffer with priority classes | SDK events (§8.1) | Bounded memory; decision events never dropped. |
| Write-ahead spool (JSONL + fsync) | SDK when Hub is down (§8.1) | No lost decisions during outages. |
| Exponential backoff with full jitter | SDK retries, outbox (§8.1, §9.4) | Avoids thundering-herd retries. |
| Circuit breaker | Hub client, notifiers | Fails fast and recovers automatically when a dependency is down. |
| Bulkhead isolation (worker threads) | Notifiers, exporters (§9.4, §20) | A crashing plugin cannot take down the Hub. |
| Idempotency keys | Approvals, decisions, ingest (§9.1, §14) | Safe retries without duplicates. |
| Compare-and-set with version (optimistic concurrency) | Approval decisions, cases (§9.3) | Exactly one decision wins under races. |
| Transactional outbox | Notifications, exports (§9, §11) | No lost or phantom messages. |
| Long-polling and SSE with resume | Approval waits, dashboard (§9.2, §11.3) | Real-time updates without WebSocket complexity. |
| Hash chain + JCS + Ed25519 checkpoints | Audit log (§11, ES §8) | Tamper evidence that survives re-serialisation. |
| TypeID / UUIDv7 | All identifiers (§6.1) | Time-sortable, index-friendly, self-describing IDs. |
| Fixed and sliding window counters with leases | Budgets and rate limits (§10.2) | Accurate limits across processes; no stuck budget after crashes. |
| Cassette (record/replay) test doubles | Replay runner (§12.2) | Re-run agents without side effects. |
| Longest common subsequence alignment | Shadow compare (§12.3) | Meaningful diffs between two action sequences. |
| Content fingerprinting | Case dedupe (§12.1) | Merge repeated mistakes into one case. |
| HMAC-based redaction markers | Redaction (ES §10) | Compare equal secrets without storing them. |
| Declarative partitioning, BRIN, partial indexes | Postgres (§15.4) | Fast time queries and instant retention. |
| `FOR UPDATE SKIP LOCKED`, advisory locks, `LISTEN/NOTIFY` | Server-mode workers and fan-out (§15.4) | Safe parallel workers and replica notifications without Redis or Kafka. |
| Row-Level Security | Server mode tenancy (§15.4) | Defence in depth for multi-project servers. |
| Host/Origin checks + token + UDS permissions | Localhost security (§14.2) | Blocks DNS-rebinding and cross-site attacks on a local daemon. |

# 15. Rejected Alternatives

| Considered | For | Why rejected (for now) |
| --- | --- | --- |
| Kafka / NATS / Redis Streams | Event transport | Extra infrastructure for every user; SQLite/Postgres + outbox + LISTEN/NOTIFY meet the load targets. |
| Redis | Rate limits, kill switch, caching | Another service to run; Hub memory + database is enough at expected scale. |
| gRPC | SDK ↔ Hub protocol | Harder to debug, heavier client libraries; HTTP/JSON over UDS is fast enough and universal. |
| Express / Fastify | Hub HTTP framework | Express is slower and older; Fastify is excellent but Hono is smaller, Web-standard and runs on Bun too. |
| Prisma | ORM | Separate query-engine binary and heavier runtime; Drizzle is thinner and SQL-close. |
| Next.js | Dashboard | No need for SSR on localhost (Section 8). |
| Changesets | Releases | JavaScript-only; Release Please covers npm and PyPI together. |
| OPA / Rego | Policy language | Powerful but hard for app developers; YAML rules + CEL cover the needs. An OPA adapter could be a plugin later. |
| Rust core via WASM | Shared engine for all languages | Contributor barrier and build complexity; Python uses the Hub decision API instead (ADR-0012). |
| WebSockets | Real-time dashboard | SSE is simpler, one-directional as needed, and resumes cleanly. |

# 16. Version and Upgrade Policy

| Rule | Detail |
| --- | --- |
| Pinning | Exact versions in lockfiles; ranges (`^`) for published package dependencies so users can dedupe. |
| Runtimes | Support every Node LTS line and every non-EOL Python version; drop a line in a minor release, announced one release earlier. |
| Major upgrades | One major dependency upgrade per PR, with changelog review and full CI; never mixed with features. |
| TypeScript | Track the latest stable TypeScript; evaluate the native TypeScript compiler (Go port) for faster CI type checks once stable. |
| Security fixes | Patched within the timelines in SECURITY.md regardless of release cadence. |
| Review cadence | This document is reviewed at every minor release; changes require an ADR when they affect architecture. |

# 17. Cost Summary

| Item | Cost to the project | Cost to users |
| --- | --- | --- |
| All libraries and tools in this document | ₹0 (open source) | ₹0 |
| GitHub (org, Actions, Pages, Packages, security features) | ₹0 for public repositories | — |
| npm and PyPI publishing | ₹0 | ₹0 |
| Codecov, Scorecard, CodeQL | ₹0 for open source | — |
| Running AgentKeel locally | — | ₹0 (runs on their machine) |
| Server mode (v1.0) | — | Their own server and Postgres (any provider or on-premises) |
| Domain name | Not needed (agentkeel.github.io) | — |

# 18. Appendix

## 18.1 Glossary

| Term | Meaning |
| --- | --- |
| LTS | Long-Term Support: runtime versions maintained for about 30 months. |
| WAL | Write-Ahead Logging mode in SQLite allowing concurrent readers. |
| SSE | Server-Sent Events: one-way HTTP stream from server to browser or client. |
| OIDC | OpenID Connect; here, short-lived identity tokens from GitHub Actions used to publish packages. |
| SBOM | Software Bill of Materials. |
| C4 model | Context, Containers, Components, Code: a way to draw architecture at four zoom levels. |

## 18.2 Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Lead maintainer | Ashutosh Kumar Rao | Pending review |  |
