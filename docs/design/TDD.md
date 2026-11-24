# AgentKeel Technical Design Document v1.0

> Markdown copy of the Word document for use by contributors and Claude Code. The Word/PDF version is the formatted original; diagrams are in `flows/`.

# 1. Document Overview

This Technical Design Document (TDD) defines **how AgentKeel is built**: its architecture (HLD), the inner design of each part (LLD), the HTTP API, the database, and the decisions behind them. It implements PRD v1.0 (features F-01 to F-22, NFR-01 to NFR-18) under the engineering rules of the SDLC Strategy v1.0. The open event format is specified separately in the **Event Schema Specification**; this document refers to it as "ES".

Ten **system flows** (pages after the contents) show the most important structures and state machines in one page each, with numbered steps, key rules and the decisions (ADRs) they come from. The text below explains each in depth and adds what a picture cannot: algorithms, data structures, contracts, failure handling and limits.

## 1.1 Audience and how to read

| Reader | Start with |
| --- | --- |
| New contributor | Sections 3 (architecture), 5 (packages), then the LLD section of the area you work on. |
| Security reviewer | Sections 3, 17, 18, and Flows 3, 4, 5. |
| SDK or adapter author | Sections 8, 13, 14 and the Event Schema Spec. |
| Operator running server mode | Sections 15, 16, 17, 22 and Flow 10. |
| Claude Code (build prompts) | One LLD section at a time, plus ADRs it references. |

## 1.2 Design principles

| Principle | Consequence in the design |
| --- | --- |
| Fail safe, never fail open silently | Every error path in the decision pipeline ends in `on_error` (default block) and an `engine.error` event. |
| Pure core, replaceable edges | Policy and core packages are pure TypeScript with ports; storage, transport, notifiers and frameworks are adapters (hexagonal architecture). |
| One data model | Every module reads and writes events in the ES format; projections are derived, never a second source of truth. |
| Local first, server optional | Default is one process plus SQLite on a laptop; the same code scales to stateless replicas on Postgres. |
| Hot path is sacred | No disk, network or lock on the allow path except when a limit or approval explicitly needs shared state. |
| Boring technology | Mature, widely used libraries; no exotic infrastructure (no Kafka, no Redis) for v1.0. |

# 2. Architecture Drivers

Architecture is shaped by the few qualities that matter most. They are ranked, so when two conflict the higher one wins.

| Rank | Quality attribute | Scenario (stimulus → response) | Source |
| --- | --- | --- | --- |
| 1 | Safety | Policy engine crashes during an action → action is blocked (or per `on_error`), agent gets a structured denial, event recorded. | NFR-04, ADR-0011 |
| 2 | Integrity | Someone edits a stored event → `agentkeel verify` reports the first broken sequence number. | F-08 |
| 3 | Performance | 1,000 actions per second through one SDK with 200 rules → p95 decision overhead < 2 ms in-process. | NFR-01/02 |
| 4 | Privacy | Default install, agent handles customer emails → no byte leaves the machine; secrets masked before storage. | NFR-09/10 |
| 5 | Usability (DX) | New user runs `npx agentkeel init` → first blocked action shown in under 5 minutes. | NFR-14 |
| 6 | Extensibility | Community wants a Discord notifier → written as a plugin, no core change. | F-20 |
| 7 | Scalability | Team of 50 agents on one server → add Hub replicas; store sustains ≥ 10k events/s. | NFR-03, F-21 |
| 8 | Portability | Runs on Linux, macOS, Windows; Node 22/24, Bun, Python 3.11+. | NFR-11 |

## 2.1 Constraints

- **Budget zero:** no paid infrastructure; everything runs on the user's machine or their own server.
- **One maintainer at start:** the design must be small enough to build in Dec 2026 to Feb 2027 for v0.1 and be easy to review.
- **No domain:** nothing may depend on an AgentKeel-hosted endpoint; telemetry (opt-in) uses a GitHub-hosted or self-describing endpoint decided later.
- **TypeScript first:** v0.1 ships TS only; Python arrives in v0.2 without forking the engine logic.

# 3. High-Level Architecture

AgentKeel is a **modular monolith** delivered as a set of packages from one monorepo. At runtime it has two shapes (Flow 2): the **SDK inside the agent process**, which evaluates rules in-process, and the **Keel Hub**, one per project, which owns all shared state: the event store, approvals, kill switches, limits, cases and the dashboard. Short-lived processes (MCP proxy, Claude Code hook client, Python SDK) are thin clients of the Hub.

## 3.1 Architectural style

| Style / pattern | Where it is used | Why |
| --- | --- | --- |
| Hexagonal (ports and adapters) | `policy` and `core` define ports: `EventSink`, `ApprovalGateway`, `ControlSource`, `Clock`, `Store`. Adapters implement them. | Pure, testable core; same logic embedded in SDK and Hub; storage and transport swappable. |
| Modular monolith | Hub modules (ingest, approvals, control, cases, tests, shadow) in one process with clear module boundaries. | Simple to run and debug; can be split later if ever needed. |
| Event sourcing (light) | Events are the source of truth; tables like `actions` and `approvals` are projections updated in the same transaction. | Audit, replay, shadow and Learn all need history; projections keep reads fast. |
| CQRS (light) | Writes go through ingest commands; reads use projection tables and SSE streams. | Read models tuned for dashboard and CLI without slowing writes. |
| Transactional outbox | Notifications and exports written as outbox rows inside the business transaction. | No lost or phantom notifications; at-least-once delivery with idempotency. |
| State machines | Approvals, cases, test runs, kill switches. | Explicit legal transitions; easy to test and visualise (Flows 4, 7). |
| Sidecar-style local daemon | Hub auto-started per project, reached over a Unix domain socket. | Shared state across many agent processes without a server. |

## 3.2 Runtime processes

| Process | Lifetime | Owns | Talks to |
| --- | --- | --- | --- |
| Agent process + `@agentkeel/sdk` | Long-lived (user code) | Compiled policy, control snapshot, event buffer, spool | Hub over UDS/HTTPS |
| Keel Hub (`agentkeel hub`) | Long-lived daemon; auto-started | Store, chain, approvals, control, outbox workers, dashboard | Notifiers, exporters |
| MCP proxy (`agentkeel mcp wrap`) | Lifetime of the MCP server it wraps | Child MCP server process | Hub (decisions, events) |
| Hook client (`agentkeel hook …`) | One call per tool use (< 100 ms) | Nothing | Hub (decision) |
| CLI commands | Short-lived | Nothing | Hub API v1 (same as dashboard) |
| Test runner (`agentkeel test`) | One run | Run results until stored | Hub (optional), files |

## 3.3 Hub discovery and auto-start

The SDK finds the Hub by reading `.agentkeel/run/hub.json` (socket path, port, pid, version, token file). If it is missing or the pid is dead, the SDK starts `agentkeel hub --detach` with a lock file (`hub.lock`, `O_EXCL`) so only one process wins the race, then waits up to 1.5 s for readiness. If auto-start is disabled or fails, the SDK continues in **degraded mode**: rules still evaluate in-process, events go to the spool, `ask` decisions follow `on_error`. Windows uses a named pipe (`\\.\pipe\agentkeel-<hash>`) instead of a Unix socket.

## 3.4 Why not a pure library, and why not a central server?

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| Library only (everything in-process) | Simplest install | No shared kill switch or budgets across processes; no approvals listener; multiple writers corrupt the chain | Rejected |
| Central server only | One place for everything | Network on every decision; needs hosting; fails the 5-minute setup and local-first goals | Rejected for default; offered as Mode B |
| **Embedded engine + local Hub (chosen)** | Fast decisions in-process; shared state in one place; still zero-config | Two shapes to test; Hub lifecycle to manage | **Chosen (ADR-0002)** |

# 4. Architecture Decision Records

Every significant decision is recorded as an ADR in `adr/` using the MADR template (context, options, decision, consequences). This table is the index; full ADR files are created in week 3 of the setup plan.

| ADR | Decision | Main reason |
| --- | --- | --- |
| 0001 | TypeScript monorepo (pnpm + Turborepo), hexagonal packages | Shared types across SDK, Hub, CLI, dashboard; pure testable core |
| 0002 | Embedded policy engine in SDK + local Keel Hub for shared state | Microsecond decisions with cross-process safety |
| 0003 | SQLite (WAL) by default; Postgres for server mode; one storage port | Zero-config locally, proven scale on servers |
| 0004 | Events are the source of truth; synchronous projections; spool when Hub is down | Audit, replay, Learn; no lost decisions |
| 0005 | CloudEvents 1.0 envelope for all events | Open standard, existing tooling, neutral |
| 0006 | Hub is the single writer; hash chain assigned at ingest per project | Simple, correct ordering and tamper evidence |
| 0007 | Most-restrictive-wins evaluation (block > ask > allow > default) | Rule order can never weaken safety |
| 0008 | TypeID identifiers (prefix + UUIDv7 base32) | Readable, typed, time-sortable, index-friendly |
| 0009 | REST + OpenAPI 3.1 generated from Zod; RFC 9457 errors | One schema source; standard tooling; good DX |
| 0010 | Transactional outbox + compare-and-set state machines for approvals | Exactly one decision, at-least-once notification |
| 0011 | Fail-safe defaults: `on_error: block`, `on_timeout: block` | Safety ranks above availability |
| 0012 | Python SDK and hooks are thin clients of the Hub decision API | One engine implementation; parity by construction |
| 0013 | Cases stored as YAML files in Git; store keeps an index | Reviewable in PRs; portable across machines |
| 0014 | Shadow mode never executes side-effect tools | Zero-risk evaluation on real traffic |
| 0015 | Hono as HTTP framework for the Hub | Small, fast, runtime-agnostic, first-class TypeScript and OpenAPI support |
| 0016 | Dashboard is a bundled Vite + React SPA served by the Hub (closes PRD PQ2) | No server rendering needed; tiny, offline, one port |
| 0017 | snake_case on the wire; idiomatic names inside SDKs | Matches CloudEvents and Python; stable across languages |
| 0018 | Localhost hardening: per-install token, Host/Origin checks, UDS permissions | Blocks DNS-rebinding and other local attacks |
| 0019 | Plugins: detectors in-process with time budget; notifiers/exporters in worker threads | Bulkhead isolation without hot-path overhead |
| 0020 | Release Please, OIDC trusted publishing, provenance (from SDLC Strategy) | Secure, automated releases |

# 5. Package Design

Packages are layered. A package may depend only on packages in a lower layer; `dependency-cruiser` enforces this in CI.

| Layer | Package | Responsibility | May depend on |
| --- | --- | --- | --- |
| 0 Contracts | `@agentkeel/spec` | JSON Schemas for events and policy; generated TS types and Zod schemas; error code catalogue | — |
| 1 Domain | `@agentkeel/policy` | Parse, validate, resolve packs, compile and evaluate policies. Pure. | spec |
| 1 Domain | `@agentkeel/core` | Decision pipeline, redaction, approval and case state machines, limit maths, ports | spec, policy |
| 2 Adapters | `store-sqlite`, `store-postgres` | Implement `Store` port: events, projections, outbox, migrations | core |
| 2 Adapters | `notifiers/*` | Implement `Notifier` port: Slack, Telegram, email, webhook | core |
| 2 Adapters | `adapters/*` | Framework integrations: Claude Code, OpenAI Agents SDK, LangGraph, CrewAI, Vercel AI SDK | sdk |
| 3 Runtime | `@agentkeel/sdk` | `guard()`, buffer, spool, Hub client, control snapshot, discovery | core, policy, spec |
| 3 Runtime | `@agentkeel/hub` | HTTP API, ingest, workers, SSE, serves dashboard | core, stores, notifiers |
| 3 Runtime | `@agentkeel/mcp-proxy` | MCP stdio/HTTP proxy using the SDK | sdk |
| 3 Runtime | `@agentkeel/testkit` | Replay runner, cassettes, red-team suites, JUnit reporter | core, policy, sdk |
| 4 Apps | `agentkeel` (CLI) | All commands; bundles Hub and dashboard | all runtime packages |
| 4 Apps | `@agentkeel/dashboard` | React SPA; talks only to API v1 | spec (types only) |
| — | `agentkeel` (Python) | Thin client: `guard`, buffer, spool, Hub client; generated models from spec | spec (generated) |

## 5.1 Core ports (interfaces)

*Figure 5.1  Ports used by the pure core*

```text
// packages/core/src/ports.ts  (simplified)
export interface EventSink      { emit(e: AkEvent): void; flush(): Promise<void>; }
export interface ControlSource  { snapshot(): ControlSnapshot; onChange(cb: () => void): Unsubscribe; }
export interface LimitGateway   { reserve(r: LimitRequest): Promise<Reservation>; settle(id: string, ok: boolean): Promise<void>; }
export interface ApprovalGateway{ request(a: ApprovalRequest): Promise<ApprovalHandle>;
                                  wait(h: ApprovalHandle, signal: AbortSignal): Promise<ApprovalOutcome>; }
export interface Clock          { now(): number; monotonic(): number; }
export interface Store {        // Hub only
  appendEvents(batch: AkEvent[]): Promise<AppendResult>;      // dedupe + chain + projections + outbox
  query<T>(q: ReadQuery): Promise<Page<T>>;
  tx<T>(fn: (tx: StoreTx) => Promise<T>): Promise<T>;
}
```

# 6. Domain Model and Identifiers

| Entity | Identity | Key attributes | Lifecycle |
| --- | --- | --- | --- |
| Project | `project` name (slug) | policy hash, settings, signing key id | Created by `init` |
| Session | `ses_…` | agent, version, mode (live/shadow), started/ended | Opened by SDK, closed on exit or idle 30 min |
| Trace | `trc_…` (+ W3C trace id if present) | session, input_id, root action | Implicit per task / turn |
| Action | `act_…` | tool, args (redacted), decision, matched rules, latency, cost | requested → decided → executed / denied → result |
| Approval | `apr_…` | action, approvers group, state, version, expires_at, decision | Flow 4 |
| Kill switch | `kil_…` | scope, active, reason, actor | activated → released |
| Limit counter | key = limit id + scope + window | value, max, window start | Rolling |
| Case | `cas_…` + fingerprint | expected outcome, source event, tags, status | Flow 7 |
| Test run | `run_…` | suite, mode, git sha, totals, status | queued → running → passed / failed / errored |
| Shadow pair | `shp_…` | input_id, live trace, shadow trace, diff summary | pending → paired → compared / expired |
| Event | `evt_…` | CloudEvents envelope + data (ES) | Immutable |

## 6.1 Identifier format (ADR-0008)

IDs follow the **TypeID** format: a short type prefix, an underscore and a 26-character Crockford base32 encoding of a **UUIDv7**. Example: `apr_01jq3v8k2zf9x7m4n6p5r0s1t2`. UUIDv7 starts with a millisecond timestamp, so IDs sort by creation time and keep B-tree inserts at the right edge of the index (fast writes, little page splitting). The prefix makes logs and support conversations unambiguous, and an ID pasted into the wrong API field fails validation immediately. In the database IDs are stored as 16-byte binary UUIDs (`BLOB` in SQLite, `uuid` in Postgres); the prefix is added at the API boundary.

## 6.2 Core value types

*Figure 6.1  Request and decision shapes (wire names in snake_case, ADR-0017)*

```text
type Effect = 'allow' | 'ask' | 'block';
interface ActionRequest {
  action_id: string; tool: string; args: Record<string, unknown>;     // args already redacted for storage
  agent: { name: string; version?: string }; env?: string;
  session_id: string; trace_id: string; input_id?: string; mode: 'live' | 'shadow';
  tags?: Record<string, string>; requested_at: string;                // RFC 3339
}
interface Decision {
  effect: Effect; winning_rule?: string; matched_rules: string[]; reason?: string;
  source: 'kill' | 'limit' | 'rule' | 'default' | 'on_error';
  policy_hash: string; eval_us: number; approval_id?: string;
}
```

# 7. LLD: Policy Engine

The policy engine (`@agentkeel/policy`) turns `agentkeel.yaml` into a compiled object that answers "allow, ask or block?" in microseconds. It is pure: no file system, no clock, no network. The file loading and watching live in the SDK and Hub.

1. **Parse** – YAML → AST with lines
2. **Validate** – JSON Schema (Ajv)
3. **Resolve** – `extends` packs
4. **Normalise** – defaults, ids
5. **Compile** – index + predicates
6. **Evaluate** – per action

## 7.1 Compilation

- **Parse** with the `yaml` library keeping source positions so every error says file, line and column.
- **Validate** against the policy JSON Schema (Ajv, compiled once). Unknown keys are errors, which catches typos like `efect`.
- **Resolve packs:** each `extends` entry `name@major` resolves to an installed package (`@agentkeel/pack-…` or a local path). Pack rules are prefixed (`payments/large-refund`); local rules with the same id override them. Version mismatches are errors, never silent upgrades.
- **Normalise:** apply defaults (`timeout: 10m`, `on_timeout: block`), convert durations to ms and time windows to minute ranges in the project time zone.
- **Compile predicates:** each `match` becomes a closure. Operators map to small functions; `matches` regexes are compiled once and checked for catastrophic backtracking with a safe-regex test at compile time; `when` (CEL subset) is parsed and type-checked once.
- **Build the index:** exact tool names go into a `Map<string, Rule[]>`; glob patterns are compiled with picomatch into an array; a per-tool LRU cache (1,024 entries) memoises "which rules can match this tool name".
- **Hash:** SHA-256 of the canonical JSON of the normalised policy, stored in every decision.

## 7.2 Evaluation algorithm

*Figure 7.1  Evaluation (pseudo-code)*

```text
function evaluate(p: CompiledPolicy, req: ActionRequest, ctl: ControlSnapshot, lim: LimitResult): Decision {
  const t0 = hrtime();
  if (ctl.isKilled(req.agent.name, req.tool))       return done('block', 'kill');
  if (lim.breached)                                 return done(lim.effect, 'limit', [lim.limitId]);
  const candidates = p.candidatesFor(req.tool);     // exact map ∪ cached glob matches
  let worst: Effect | null = null; const matched: string[] = []; let winner;
  for (const r of candidates) {
    if (!r.test(req)) continue;                     // predicates; each guarded by try/catch
    matched.push(r.id);
    if (rank(r.effect) > rank(worst)) { worst = r.effect; winner = r; }
  }                                                 // rank: block 3 > ask 2 > allow 1
  return worst ? done(worst, 'rule', matched, winner) : done(p.default, 'default');
}
```

**Complexity:** O(k) where k is the number of candidate rules for the tool name, usually under 10 even with hundreds of rules, because the index removes rules for other tools. All matched rules are evaluated (not just until the first block) so `explain` and the dashboard can show every rule that applied; the cost is bounded because k is small.

**Error handling:** if a predicate throws (bad CEL expression at runtime, unexpected type), evaluation stops and returns `on_error` with source `on_error`, plus the error in the decision for `engine.error`. Detector plugins have a 1 ms time budget each; exceeding it counts as an error.

## 7.3 Invariants (property-tested)

| Invariant | Test |
| --- | --- |
| Order independence | Shuffling rule order never changes the effect (fast-check, 10,000 random policies). |
| Monotonic safety | Adding a `block` rule never turns block/ask into allow; adding an `allow` rule never turns block into anything else. |
| Determinism | Same compiled policy + same request + same control state → same decision. |
| Kill dominance | Any active kill scope covering the request always yields block. |
| Totality | Every request gets exactly one decision; no exception escapes `evaluate`. |

## 7.4 Hot reload

The SDK and Hub watch `agentkeel.yaml` (and pack folders) with a 200 ms debounce. A change triggers a full compile in the background. On success the reference to the compiled policy is swapped atomically (copy-on-write; in-flight evaluations finish on the old object) and a `policy.loaded` event is emitted with the new hash. On failure the last good policy stays active and a `policy.invalid` event is emitted with line-level errors. The Hub also broadcasts the active policy hash on the control stream so the dashboard can warn if an agent runs an older policy.

# 8. LLD: SDK and Decision Pipeline

Flow 3 shows the decision path. The SDK wraps a tool so that the path runs before the tool function and the outcome is recorded after it.

*Figure 8.1  guard() pseudo-code*

```text
export function guard<A, R>(tool: ToolFn<A, R>, opts: GuardOptions): ToolFn<A, R | Denied> {
  return async (args: A, ctx?: CallCtx) => {
    const req  = buildRequest(opts, args, ctx);                 // ids, context, input_id
    const safe = redact(req, project.redaction);                // never store raw secrets
    sink.emit(ev('action.requested', safe));
    let d: Decision;
    try {
      const lim = opts.limits ? await limits.reserve(safe) : NO_LIMIT;   // only if a limit matches
      d = evaluate(policy.current(), safe, control.snapshot(), lim);
      if (d.effect === 'ask') d = await approvals.resolve(safe, d, ctx?.signal);
    } catch (err) { d = onError(err); sink.emit(ev('engine.error', err)); }
    sink.emit(ev('policy.decided', d));
    if (d.effect !== 'allow' || safe.mode === 'shadow' && !opts.sideEffectFree) {
      await limits.release(d); sink.emit(ev('action.denied', d));
      return denial(d, opts.onDeny);                            // return object or throw AgentKeelDenied
    }
    const t = monotonic();
    try { const r = await tool(args, ctx); sink.emit(ev('action.result', ok(r, t))); return r; }
    catch (e) { sink.emit(ev('action.result', fail(e, t))); throw e; }   // tool errors pass through
  };
}
```

## 8.1 Event buffer and spool

| Aspect | Design |
| --- | --- |
| Buffer | In-memory ring buffer, capacity 10,000 events. Two priority classes: **critical** (`action.requested`, `policy.decided`, `action.denied`, `approval.*`, `engine.error`) and **normal** (`action.result`). |
| Flush | Every 200 ms or 100 events, whichever first; payload gzip; one in-flight request at a time per process (keeps ordering). |
| Backpressure | If the buffer is 80 % full, `action.result` payloads are trimmed to metadata; if 100 % full, critical events bypass the buffer and are appended synchronously to the spool. |
| Spool | `.agentkeel/spool/<pid>-<n>.jsonl`, append-only, `fsync` per batch, rotated at 8 MB. Drained by the Hub on start and every 5 s; files deleted after successful ingest. |
| Shutdown | `beforeExit`/`SIGTERM` hooks flush with a 2 s deadline, then spool the remainder. |
| Retries | Exponential backoff with full jitter (100 ms base, 10 s cap); circuit breaker opens after 5 consecutive failures for 30 s; while open, events go straight to the spool. |

## 8.2 Control snapshot

The SDK subscribes to `GET /v1/control/stream` (Server-Sent Events). Each message carries a monotonically increasing `control_version`, the set of active kill scopes and the active policy hash. If the stream drops, the SDK polls `GET /v1/control` every second. A snapshot older than 5 s is **stale**: decisions continue with the last snapshot, events carry `control_stale=true`, and `on_control_stale: block` can make it strict for high-risk projects.

## 8.3 Python SDK (v0.2, ADR-0012)

The Python SDK calls `POST /v1/decisions` on the Hub for every guarded call (typically 0.3–1 ms over a Unix socket), so there is only one engine implementation. It shares the buffer, spool and retry design. A future embedded Python evaluator may be added if needed; it would have to pass the same conformance vectors before release.

# 9. LLD: Approvals

Flow 4 shows the approval state machine. This section covers creation, waiting, notification and concurrency.

## 9.1 Creation

`POST /v1/approvals` with an `Idempotency-Key` equal to the action id. In one transaction the Hub inserts the approval (`state=pending`, `version=1`, `expires_at=now+timeout`), the `approval.requested` event, and one outbox row per configured channel. A retry with the same key returns the same approval (no duplicates even if the SDK times out and retries).

## 9.2 Waiting

The SDK waits with **long-polling**: `GET /v1/approvals/{id}?wait=25s` returns as soon as the state changes or after 25 s, then the SDK polls again until `expires_at`. Long-polling works through every proxy and over Unix sockets, and has no extra dependency. The dashboard uses the SSE stream instead. If the agent aborts (abort signal, process exit), the SDK sends `POST /v1/approvals/{id}:cancel`.

## 9.3 Deciding (exactly one winner)

*Figure 9.1  Compare-and-set decision*

```text
UPDATE approvals
   SET state = :new_state, decided_by = :actor, decided_via = :channel,
       comment = :comment, decided_at = :now, version = version + 1
 WHERE id = :id AND state = 'pending' AND version = :expected_version
RETURNING version;
-- 0 rows → 409 Conflict (someone else decided first, or it expired); the caller re-reads.
```

Before the update the Hub checks that the actor is in the rule's approver group for that channel (Slack user ID, Telegram user ID, dashboard user) and, if `separate_approver` is set, that the actor is not the agent's owner. Failed checks record `approval.refused` and leave the state unchanged. Timeouts are handled by a timer worker that scans `pending` approvals by `expires_at` (indexed) every second and applies the same compare-and-set with `state=expired`.

## 9.4 Notifier workers

| Concern | Design |
| --- | --- |
| Delivery | Outbox worker claims rows (`status=pending`, `next_attempt_at <= now`) in small batches, calls the notifier, marks `sent` with the provider message id. |
| Retries | Exponential backoff with jitter up to 10 attempts; then `dead` and a dashboard warning. Per-channel circuit breaker. |
| Slack | Bolt for JS in **Socket Mode** (outbound WebSocket, no public URL). Block Kit message with Approve/Reject buttons carrying approval id + version. After a decision, `chat.update` replaces buttons with the result. |
| Telegram | Bot API with long-polling `getUpdates` (no webhook URL). Inline keyboard buttons with signed callback data (HMAC of approval id + version) so callbacks cannot be forged or replayed. |
| Isolation | Notifiers run in a worker thread per channel (ADR-0019); a crash restarts the worker, never the Hub. |
| Reminders | At 50 % of the timeout an optional reminder is sent to the same thread. |

# 10. LLD: Kill Switch and Limits

Flow 6 shows how shared safety state is pushed to agents and how budgets are reserved.

## 10.1 Kill switch

- `kill_switches` rows have a scope (`all`, `agent:<name>`, `tool:<glob>`), `active`, reason and actor. Activating writes the row, a `kill.activated` event and increments `control_version` in one transaction.
- The control stream pushes the new snapshot; SDKs apply it before the next decision. Measured target: < 1 s from command to block (FR-05.1).
- Kill state is persisted, so it survives Hub and agent restarts until `agentkeel resume`.
- In-flight approvals covered by a new kill scope are moved to `cancelled`.

## 10.2 Limits

| Limit type | Algorithm | Storage |
| --- | --- | --- |
| Budget (`sum` of an argument per window) | Fixed windows aligned to the project time zone (e.g. calendar day). Reservation: compare-and-add on the current window row; settle on result; release on denial or failure. | `limit_counters(key, window_start, value, max)` + `limit_reservations` |
| Rate (`max` calls per period) | Sliding window approximation with two fixed windows weighted by overlap (as used by large API gateways): count = prev × (1 − elapsed/period) + current. | Same table, value = count |
| Loop detection | Hash of (tool, canonical redacted args); if the same hash occurs N times in M seconds in one session → effect (default block). | In-memory per SDK process + Hub check for multi-process sessions |

Reservations have a 60 s lease; a worker releases expired leases so a crashed agent cannot hold budget forever. Only actions that match a limit pay the round-trip to the Hub; all others stay on the in-process fast path.

# 11. LLD: Event Ingestion and Storage

Flow 5 shows the write path. The Hub is the only writer of the store (ADR-0006), which makes ordering, deduplication and the hash chain simple and correct.

## 11.1 Ingest transaction

*Figure 11.1  One ingest batch*

```text
BEGIN IMMEDIATE;                                   -- SQLite: take the write lock up front
  head := SELECT seq, hash FROM chain_heads WHERE project_id = ?;
  FOR e IN batch (already schema-validated):
    INSERT INTO events(...) VALUES(...) ON CONFLICT(id) DO NOTHING;
    IF inserted:
      head.seq  += 1
      e.hash     = sha256(head.hash || jcs(e_without_chain_fields))
      UPDATE events SET seq = head.seq, prev_hash = head.hash, hash = e.hash WHERE id = e.id;
      head.hash  = e.hash
      apply_projection(e)                          -- actions, approvals, sessions, traces, …
      enqueue_outbox(e)                            -- exporters, notifications if needed
  UPDATE chain_heads SET seq = head.seq, hash = head.hash WHERE project_id = ?;
COMMIT;                                            -- then NOTIFY / in-process fan-out to SSE
```

- **Batching** amortises the write lock and `fsync`: 100–500 events per transaction gives > 2,000 events/s on a laptop SSD (NFR-03) with SQLite in WAL mode and `synchronous=NORMAL`.
- **Per-item results:** the API returns 207 Multi-Status style results (`accepted`, `duplicate`, `invalid` with reason) so one bad event never rejects the batch.
- **Ordering:** `seq` (server order) is authoritative for the chain and for streaming; client `time` is kept for display and analysis. Clock skew never breaks the chain.
- **Payload size:** events over 64 KB have large fields truncated with a size marker locally; in server mode they can go to object storage with a content hash reference.

## 11.2 Projections

| Projection | Built from | Serves |
| --- | --- | --- |
| `sessions`, `traces` | `session.*`, any event with new trace id | Activity feed grouping, trace view |
| `actions` | `action.requested` + `policy.decided` + outcome + result | Feed, filters, explain, replay input |
| `approvals` | `approval.*` | Inbox, waiting SDKs, timers |
| `rule_stats` | `policy.decided` | Hit counts on the Policies screen |
| `cases_index` | Case files + `case.*` | Case library, test selection |
| `test_runs`, `test_results` | `test.*` | Tests screen, CI comments |
| `shadow_pairs` | `shadow.paired` + traces | Shadow compare |

Projections are rebuildable: `agentkeel hub rebuild-projections` truncates them and replays all events in `seq` order. This is also how schema changes to read models are migrated safely.

## 11.3 Streaming to readers

`GET /v1/stream?topics=actions,approvals` is an SSE stream. Each message id is the event `seq`, so a reconnecting client sends `Last-Event-ID` and receives everything after it from the store before switching to live. In server mode, replicas use Postgres `LISTEN/NOTIFY` on a per-project channel to learn about new commits and push to their own SSE clients.

# 12. LLD: Learn, Test and Shadow

## 12.1 Case files (Learn, Flow 7)

*Figure 12.1  A case file*

```text
# agentkeel/cases/refund-ask-2f9c1e.yaml
id: cas_01jq9h3a7c6r2t8w0x4y5z6b7d
fingerprint: 2f9c1e…            # sha256(tool, rule id, normalised args shape + key values)
status: active                   # proposed | active | quarantined | archived | merged
source: { event: evt_01jq…, kind: approval.rejected, captured_at: 2027-04-02T10:15:00Z }
request:
  tool: refund
  args: { order_id: "[REDACTED:id:9a1b]", amount: 1200, currency: INR }
  agent: { name: support-bot, version: 1.4.0 }
expect: { decision: ask }        # or block | allow | tool_not_called
seen_count: 3
tags: [payments, high-value]
note: "Refunds above 500 must ask, even for VIP customers"
```

Capture runs in the Hub on `action.denied` and `approval.rejected` events (and on "flag as wrong"). The capture worker redacts again with the strictest rules, runs a secret scanner over the YAML text, computes the fingerprint, and either writes a new file in `proposed` state or increments `seen_count` on the existing case (merge). Files are written atomically (write to temp, rename).

## 12.2 Replay runner (Test, Flow 8)

| Mode | How it works | Cost |
| --- | --- | --- |
| Policy-only | For each case: compile current policy once, evaluate the stored `ActionRequest`, compare with `expect`. Parallel across CPU cores with worker threads. | No model calls; 1,000 cases < 10 s |
| Agent mode | Imports the user's `agentkeel.test.ts` (or `.py`) which exports `run(input, tools)`. Each tool is replaced by a **cassette double**: responses recorded in the source trace, keyed by (tool, canonical args hash). Unrecorded calls return an error result and are reported. The guarded calls the agent makes are captured and judged. | Model calls by the user's agent; tools never execute |

Each case runs `repeats` times (default 3). All pass → pass; all fail → fail; mixed → flaky. The runner writes `test.run` and `test.case_result` events, a JSON report and a JUnit XML file, and exits with code 1 if any active case fails.

## 12.3 Shadow compare (Flow 9)

- **Pairing:** both versions tag work with the same `input_id`. The Hub creates a `shadow_pairs` row when the first trace arrives and completes it when the other arrives (expires after 24 h).
- **Doubles in shadow:** for each shadow tool call the SDK asks the Hub for the live trace's recorded response with the same (tool, args hash); if not yet available it waits up to 2 s, then uses a stub declared in the tool options.
- **Alignment:** action sequences are aligned with a longest-common-subsequence on (tool, normalised args); unmatched actions are "added" or "removed", matched actions with different decisions are "changed".
- **Summary:** per version pair: % identical inputs, added/removed/changed actions, approvals needed, blocks, cost and latency deltas. Differences can be saved as cases with one call.

# 13. LLD: MCP Proxy and Claude Code Hooks

## 13.1 MCP proxy

`agentkeel mcp wrap -- npx some-mcp-server` starts the real server as a child process and sits between the client's stdio and the child's stdio. It parses JSON-RPC 2.0 messages with a streaming, length-safe newline-delimited parser (fuzz-tested). All messages are forwarded unchanged except:

| Message | Proxy behaviour |
| --- | --- |
| `initialize` | Forwarded; server name and version recorded in a `session.started` event. |
| `tools/list` (response) | Recorded as an inventory event; tools hidden by policy (`effect: block` with `hide: true`) are removed from the list. |
| `tools/call` (request) | Turned into an `ActionRequest` (tool = `<server>.<tool>`), decided via the Hub. Allow → forwarded. Block or rejected ask → the proxy replies itself with a valid `CallToolResult` with `isError: true` and the reason text, so the client and model see a clean refusal. |
| `tools/call` (response) | Recorded as `action.result` (redacted, truncated). |
| Notifications, cancellations | Forwarded; `notifications/cancelled` for a pending approval cancels it. |

Streamable HTTP transport (v0.3) uses the same core as a reverse proxy on localhost. `agentkeel mcp install` edits the client's MCP configuration to wrap each server, writing a backup first.

## 13.2 Claude Code hooks

`agentkeel hooks install` adds `PreToolUse` and `PostToolUse` hook entries to Claude Code settings. On `PreToolUse` Claude Code runs `agentkeel hook pre` with the tool call as JSON on stdin. The hook client (a small, fast-starting entry point) calls `POST /v1/decisions` and prints Claude Code's documented hook output: allow, deny with reason, or ask. For AgentKeel `ask`, the hook waits for the Hub approval (Slack/Telegram) up to the hook timeout and then returns the result. `PostToolUse` records the result. If the Hub is unreachable the hook applies `on_error` (default deny) and tells the user how to start the Hub.

# 14. API Design

The Keel Hub exposes one HTTP API, **v1**, used by SDKs, the CLI, the dashboard, the hook client and the MCP proxy. There are no private endpoints: what the dashboard can do, a script can do. The API follows widely adopted public API design practice (resource-oriented URLs, Google AIP-style custom methods, IETF standards for errors, idempotency and rate limiting).

## 14.1 Conventions

| Topic | Convention |
| --- | --- |
| Base and versioning | `/v1/…`. Additive changes (new fields, endpoints) within v1; breaking changes only in `/v2` with 6 months of overlap. `AgentKeel-Version` response header gives the server version. |
| Resources | Plural nouns: `/v1/approvals/{id}`. Custom actions use a colon: `/v1/approvals/{id}:cancel`, `/v1/policy:validate`, `/v1/events:batch`. |
| Format | JSON, UTF-8, snake_case fields, RFC 3339 timestamps in UTC, TypeIDs for ids, money as integer minor units or decimal strings. |
| Schema source | Zod schemas in `@agentkeel/spec` → OpenAPI 3.1 document generated at build time and published with the docs. Clients (TS, Python) are generated from it. |
| Errors | RFC 9457 Problem Details (`application/problem+json`) with extension fields `code` (`AK-1203`), `request_id`, and `errors[]` for field-level validation. |
| Idempotency | `Idempotency-Key` header on all non-idempotent POSTs; keys stored 24 h with the response; same key + different body → 422. |
| Concurrency | Mutable resources return `ETag` (version). Updates require `If-Match`; mismatch → 412 Precondition Failed. |
| Pagination | Cursor-based: `?limit=50&cursor=…`; response `{ data: [...], next_cursor }`. Cursor is an opaque, signed encoding of the last (`seq` or time, id). Max limit 500. |
| Filtering and sorting | Explicit query parameters (`agent`, `tool`, `decision`, `since`, `until`); `order=asc\|desc` on time. No free-form query language in v1. |
| Long-running work | Test runs, simulations, exports: `202 Accepted` + `Location: /v1/operations/{id}`; poll or stream. |
| Rate limiting | Server mode: per API key token bucket; `RateLimit-Policy` and `RateLimit` headers (IETF draft) and `Retry-After` on 429. |
| Compression | gzip/br responses; gzip request bodies accepted on `events:batch`. |
| Tracing | Accepts W3C `traceparent`; every response has `X-Request-Id`. |

## 14.2 Example: deciding an approval

*Figure 14.1  Request and responses*

```text
POST /v1/approvals/apr_01jq3v8k2zf9x7m4n6p5r0s1t2:decide
Authorization: Bearer …            If-Match: "3"            Idempotency-Key: 7b1e…
{ "decision": "approved", "comment": "Customer verified on call" }

200 OK                               ETag: "4"
{ "id": "apr_01jq3v8k…", "state": "approved", "version": 4, "decided_by": "slack:U04ABC",
  "decided_via": "dashboard", "decided_at": "2027-04-02T10:15:07Z", "action_id": "act_01jq…" }

409 Conflict   (someone decided first)       Content-Type: application/problem+json
{ "type": "https://agentkeel.github.io/errors/AK-2301", "title": "Approval already decided",
  "status": 409, "code": "AK-2301", "detail": "Approval was rejected by telegram:5512 at 10:15:05Z",
  "request_id": "req_01jq…" }
```

## 14.3 Authentication and authorisation

| Mode | Mechanism |
| --- | --- |
| Local (Unix socket / named pipe) | Socket file mode 0600 in a 0700 directory; plus bearer token from `~/.agentkeel/token` (0600). Peer credentials checked where the OS supports it. |
| Local (127.0.0.1:7471 for dashboard) | Bearer token for API; dashboard gets a session cookie (HttpOnly, SameSite=Strict) after opening a one-time URL printed by `agentkeel ui`. `Host` must be `localhost`/`127.0.0.1` and `Origin` must match, blocking DNS-rebinding and cross-site requests (ADR-0018). |
| Server mode | API keys `ak_live_<id>_<secret>` stored as SHA-256 hashes with scopes (`ingest`, `decide`, `approve`, `admin`) and project binding. Humans log in with OIDC or email magic link; roles viewer / approver / admin. |
| Approvals from chat | Identity from Slack/Telegram user IDs verified by the platform connection, mapped to approver groups in the policy file. |

## 14.4 Endpoint catalogue

| Method and path | Purpose | Notes |
| --- | --- | --- |
| `POST /v1/decisions` | Evaluate an `ActionRequest` (thin clients) | Idempotent by `action_id`; may return `approval_id` when `ask` |
| `POST /v1/events:batch` | Ingest up to 500 events / 1 MB | Per-item results; 429 with backoff |
| `GET /v1/events` | List events (filters, cursor) | Read-only, ordered by `seq` |
| `GET /v1/traces/{id}` | Full trace with events and projections | ETag for caching |
| `GET /v1/actions` | Activity feed (filters) | Cursor pagination |
| `GET /v1/actions/{id}:explain` | Rules considered and why | FR-03.6 |
| `POST /v1/approvals` | Create approval | Idempotency-Key = action id |
| `GET /v1/approvals/{id}?wait=25s` | Get or long-poll approval | Returns on change or timeout |
| `POST /v1/approvals/{id}:decide` | Approve or reject | `If-Match` version; 409 if already decided |
| `POST /v1/approvals/{id}:cancel` | Cancel pending approval | Agent aborted or killed |
| `GET /v1/control`, `GET /v1/control/stream` | Control snapshot / SSE | Kill scopes, policy hash, version |
| `POST /v1/kill-switches`, `POST /v1/kill-switches/{id}:release` | Activate / release kill | Reason required |
| `POST /v1/limits:reserve`, `POST /v1/limits/reservations/{id}:settle` | Budget and rate reservations | 60 s lease |
| `GET /v1/policy`, `POST /v1/policy:validate`, `POST /v1/policy:simulate` | Active policy, validation, what-if | Simulate is long-running |
| `GET\|POST /v1/cases`, `PATCH /v1/cases/{id}` | Case library | `If-Match`; writes case files |
| `POST /v1/test-runs`, `GET /v1/test-runs/{id}` | Start and read test runs | 202 + operation |
| `GET /v1/shadow/comparisons` | Shadow pairs and summaries | Filter by version pair |
| `GET /v1/stream` | SSE for dashboard and `tail` | `Last-Event-ID` resume |
| `POST /v1/data:purge`, `POST /v1/exports` | Deletion requests, exports | Recorded as events |
| `GET /healthz`, `GET /readyz`, `GET /metrics` | Liveness, readiness, Prometheus metrics | No auth for health on UDS only |

# 15. Database Design

One logical schema, two physical engines: **SQLite** (default, one file per project at `.agentkeel/agentkeel.db`) and **Postgres** (server mode). Both are accessed through the `Store` port with Drizzle ORM for typed queries and hand-written SQL for the hot ingest path. Migrations are versioned SQL files per engine, applied automatically by the Hub at start with a schema lock.

## 15.1 Entity relationships

*Figure 15.1  Logical model*

```text
projects 1─* sessions 1─* traces 1─* actions 1─0..1 approvals
    │            │            └──────* events (append-only, hash-chained, seq)
    │            └─ mode (live | shadow), agent, version
    ├─1 chain_heads           ├─* kill_switches        ├─* limit_counters ─* limit_reservations
    ├─* outbox                ├─* cases_index          ├─* test_runs 1─* test_results
    ├─* shadow_pairs (live_trace_id, shadow_trace_id)   └─* idempotency_keys
```

## 15.2 Core tables (SQLite DDL, simplified)

*Figure 15.2  Main tables*

```text
CREATE TABLE events (
  id            BLOB PRIMARY KEY,            -- UUIDv7 (16 bytes)
  project_id    TEXT NOT NULL,
  seq           INTEGER NOT NULL,            -- per project, gapless, assigned at ingest
  type          TEXT NOT NULL,               -- dev.agentkeel.action.requested
  time          TEXT NOT NULL,               -- client time (RFC 3339)
  ingested_at   TEXT NOT NULL,
  session_id    BLOB, trace_id BLOB, action_id BLOB,
  data          BLOB NOT NULL,               -- JSON (JSONB-compatible text in SQLite)
  prev_hash     BLOB NOT NULL, hash BLOB NOT NULL,
  UNIQUE (project_id, seq)
) STRICT;
CREATE INDEX ev_trace  ON events(trace_id, seq);
CREATE INDEX ev_type_t ON events(project_id, type, seq);

CREATE TABLE actions (
  id BLOB PRIMARY KEY, project_id TEXT NOT NULL, session_id BLOB NOT NULL, trace_id BLOB NOT NULL,
  tool TEXT NOT NULL, agent TEXT NOT NULL, agent_version TEXT, mode TEXT NOT NULL,
  decision TEXT, decision_source TEXT, winning_rule TEXT, matched_rules TEXT,   -- JSON array
  outcome TEXT,  -- executed | denied | error
  latency_ms INTEGER, cost_micros INTEGER, requested_at TEXT NOT NULL, input_id TEXT
) STRICT;
CREATE INDEX act_feed ON actions(project_id, requested_at DESC);
CREATE INDEX act_tool ON actions(project_id, tool, requested_at DESC);
CREATE INDEX act_dec  ON actions(project_id, decision, requested_at DESC);

CREATE TABLE approvals (
  id BLOB PRIMARY KEY, action_id BLOB NOT NULL UNIQUE, project_id TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('pending','approved','rejected','expired','cancelled')),
  version INTEGER NOT NULL DEFAULT 1, approver_group TEXT NOT NULL, rule_id TEXT NOT NULL,
  expires_at TEXT NOT NULL, decided_by TEXT, decided_via TEXT, comment TEXT, decided_at TEXT, created_at TEXT NOT NULL
) STRICT;
CREATE INDEX apr_pending ON approvals(expires_at) WHERE state = 'pending';

CREATE TABLE outbox (
  id INTEGER PRIMARY KEY, project_id TEXT NOT NULL, kind TEXT NOT NULL, payload BLOB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT NOT NULL, last_error TEXT, provider_ref TEXT
) STRICT;
CREATE INDEX outbox_due ON outbox(next_attempt_at) WHERE status = 'pending';

CREATE TABLE chain_heads (project_id TEXT PRIMARY KEY, seq INTEGER NOT NULL, hash BLOB NOT NULL) STRICT;
CREATE TABLE kill_switches (id BLOB PRIMARY KEY, project_id TEXT NOT NULL, scope TEXT NOT NULL,
  active INTEGER NOT NULL, reason TEXT NOT NULL, actor TEXT NOT NULL, created_at TEXT NOT NULL, released_at TEXT) STRICT;
CREATE TABLE limit_counters (key TEXT NOT NULL, window_start TEXT NOT NULL, value REAL NOT NULL,
  max REAL NOT NULL, PRIMARY KEY (key, window_start)) STRICT;
CREATE TABLE idempotency_keys (key TEXT PRIMARY KEY, request_hash BLOB NOT NULL,
  response BLOB NOT NULL, created_at TEXT NOT NULL) STRICT;
```

## 15.3 SQLite configuration

| Setting | Value | Reason |
| --- | --- | --- |
| `journal_mode` | WAL | Readers never block the writer; dashboard reads during ingest. |
| `synchronous` | NORMAL | Durable at checkpoint with WAL; big write speed-up. Decision events also exist in the spool until acknowledged. |
| `busy_timeout` | 5000 ms | CLI reads wait instead of failing during checkpoints. |
| `foreign_keys` | ON | Integrity of projections. |
| `wal_autocheckpoint` | 1000 pages + periodic `PRAGMA wal_checkpoint(TRUNCATE)` when idle | Keeps the WAL file small. |
| Tables | `STRICT` | Type checking at the database level. |

## 15.4 Postgres differences (server mode)

- **Types:** `uuid` ids, `jsonb` data, `bytea` hashes, `timestamptz` times.
- **Partitioning:** `events` and `actions` are range-partitioned by month on `ingested_at`/`requested_at` (declarative partitioning). Retention drops whole partitions, which is instant and avoids vacuum load.
- **Indexes:** B-tree on (project_id, seq); BRIN on time columns of large partitions; partial indexes for pending approvals and due outbox rows; GIN on `data` only where a query needs it.
- **Tenancy:** every row has `project_id`; Row-Level Security policies use `current_setting('ak.project_id')` set per transaction, as a second line of defence behind application checks.
- **Chain lock:** `SELECT … FROM chain_heads WHERE project_id = $1 FOR UPDATE` once per batch serialises chain writes per project while different projects ingest in parallel.
- **Workers:** outbox, timers and retention jobs claim work with `FOR UPDATE SKIP LOCKED`; singleton jobs use `pg_try_advisory_lock`.

## 15.5 Migrations and retention

Migrations are forward-only SQL files (`0001_init.sql`, …) per engine, checked in CI against both engines with the same test suite. The Hub refuses to start against a database newer than itself. Retention runs hourly: SQLite deletes in batches of 5,000 rows by time; Postgres drops expired partitions. Before pruning, a `retention.pruned` event records the last pruned `seq` and hash so the chain remains verifiable from that point (ES §8).

# 16. Scalability and Performance

## 16.1 Latency budget for one allowed action

| Step | Budget (p95) | How it is achieved |
| --- | --- | --- |
| Build request + redaction | 0.3 ms | Key-based masking first; value detectors only on string fields; precompiled regexes |
| Kill check | 0.01 ms | In-memory snapshot lookup |
| Rule evaluation (200 rules) | 0.5 ms | Tool index, cached glob matches, precompiled predicates |
| Event emit | 0.05 ms | Push to ring buffer; I/O is asynchronous |
| Total SDK overhead | < 2 ms | NFR-01; benchmark fails CI on > 20 % regression |
| Thin client (`POST /v1/decisions` over UDS) | < 5 ms | Keep-alive connection, small JSON, no disk write on the response path |
| MCP proxy added latency | < 10 ms | Streaming parser, no extra process hop beyond the proxy itself |

## 16.2 Capacity estimates

| Scenario | Load | Storage | Fits? |
| --- | --- | --- | --- |
| Solo developer, Claude Code | ~2,000 actions/day ≈ 10,000 events/day | ~1 KB/event → 10 MB/day, 300 MB per 30 days | Yes, SQLite |
| Startup support bot | 20 actions/s peak ≈ 100 events/s | ~260 GB/month at full peak; realistic 20–40 GB with trimming and 30-day retention | Yes, SQLite on SSD; Postgres recommended for teams |
| Team server, 50 agents | 500 actions/s ≈ 2,500 events/s | ~6 TB/month raw; needs payload trimming, compression and 14–30 day retention | Postgres with partitioning; 2–3 Hub replicas |

## 16.3 Scaling techniques

- **Stateless Hub replicas** behind a load balancer (Flow 10); any replica serves any request.
- **Batch everything:** SDK batches events; ingest commits batches; outbox workers claim batches.
- **Partitioned tables** for events and actions; time-bounded queries hit few partitions.
- **Chain contention control:** one lock per batch per project; projects scale independently. For very large single projects, a future option is per-shard chains joined by signed checkpoints (ES §8).
- **Read scaling:** dashboards read projections, not raw events; heavy analytics should use exporters (OTel, Langfuse) rather than the operational store.
- **Caching:** compiled policies cached by hash; tool→rules LRU; ETags for traces and approvals so browsers and CLIs revalidate cheaply.
- **Beyond one Postgres primary:** shard by `project_id` (documented design; not built in v1.0, as no expected user needs it).

# 17. Reliability and Failure Modes

A failure mode and effects analysis (FMEA) for the parts that can hurt users most. Every row is covered by a chaos or integration test (SDLC Strategy §7).

| Failure | Effect without design | Design response | Detected by |
| --- | --- | --- | --- |
| Hub not running / crashes | No events, no approvals | Rules still evaluate in-process; events to spool; `ask` → `on_error`; SDK auto-restarts Hub | `engine.error`, `doctor` |
| Policy file invalid after edit | Agent runs with no policy | Last good policy stays active; `policy.invalid` event and CLI/dashboard warning | Hot-reload test |
| Predicate throws at runtime | Exception reaches agent | Caught; `on_error` decision; error recorded | Property tests |
| Disk full | Lost events | Hub returns 507; SDK keeps critical events in memory up to cap, then denies risky tools per `on_error` | Chaos test |
| Slack / Telegram down | Approvals never arrive | Retries, breaker; approval still visible in CLI and dashboard; timeout applies | Outbox metrics |
| Two approvers click at once | Double decision | Compare-and-set; one wins, other gets 409 and a friendly "already decided" message | Concurrency test |
| Agent process killed mid-approval | Orphan approval | Waiter heartbeat; cancelled after grace period | Timer worker |
| Crash during ingest transaction | Half-written chain | Single transaction; spool re-sent; dedupe by id | Crash test |
| Clock skew between processes | Wrong ordering | Server `seq` authoritative; monotonic clocks for durations | Unit tests |
| Corrupted database file | Total data loss | `agentkeel verify`, nightly online backup (`VACUUM INTO`) option, events exportable as JSONL | `verify`, `doctor` |

# 18. Security Architecture

## 18.1 Threat model (STRIDE)

| Threat | Example against AgentKeel | Mitigation |
| --- | --- | --- |
| Spoofing | Fake approver clicks Approve; forged Telegram callback | Channel user-ID allowlists; HMAC-signed callback data; Slack Socket Mode authenticated connection |
| Tampering | Agent (or attacker) edits `agentkeel.yaml` or the database to allow itself | Built-in non-overridable rule protecting `agentkeel.yaml`, `.agentkeel/` and `~/.agentkeel/` from guarded tools; hash chain + signed checkpoints; policy hash in every decision |
| Repudiation | "I never approved that refund" | Approver identity, channel, time and comment recorded in the hash-chained log |
| Information disclosure | Secrets in tool args end up in logs, cases or exports | Redaction before storage; secret scanner on case files; no telemetry by default; exports redacted |
| Denial of service | Event flood fills disk; regex causes CPU spin | Rate limits and 429; payload caps; safe-regex check at compile time; retention |
| Elevation of privilege | Web page in the user's browser calls localhost Hub (DNS rebinding / CSRF) | Token auth, Host and Origin checks, SameSite cookies, no CORS, UDS for SDKs |
| Prompt injection | Tool output tells the agent to call `delete_all` | Out of AgentKeel's control for the model, but the **action** is still checked by policy; red-team suite tests this |

## 18.2 Keys and secrets

| Item | Where | Protection |
| --- | --- | --- |
| Local API token | `~/.agentkeel/token` | Random 256-bit; file mode 0600; rotated with `agentkeel hub rotate-token` |
| Checkpoint signing key | `~/.agentkeel/keys/<project>.ed25519` | 0600; public key stored in the project and in checkpoints |
| Slack / Telegram tokens | Environment variables or OS keychain (via `keytar`-style adapter), referenced from config as `env:SLACK_APP_TOKEN` | Never written into `agentkeel.yaml` or events |
| Redaction salt | Per project, in `.agentkeel/salt` | Used for HMAC in `[REDACTED:type:hmac8]` so equal values match without being revealed |
| Server API keys | Postgres, hashed | Shown once at creation; prefix for identification; scoped |

# 19. Observability of AgentKeel

AgentKeel observes agents; it must also be observable itself, without leaking agent data.

| Signal | Implementation |
| --- | --- |
| Logs | pino JSON logs; level via `AGENTKEEL_LOG`; fields: component, request_id, project; never raw args or tokens (enforced by a log redaction serializer). |
| Metrics | Prometheus `/metrics` on the Hub: decision latency histogram, ingest rate, batch size, spool size, outbox lag and dead count, approval wait time, SSE clients, DB size. |
| Traces | Optional OpenTelemetry tracing of the Hub itself (`AGENTKEEL_OTEL=1`); spans for ingest, decide, notify. |
| Health | `/healthz` (process alive), `/readyz` (DB reachable, migrations done, workers running). |
| Doctor | `agentkeel doctor` checks versions, Hub reachability, socket permissions, notifier connectivity, policy validity, spool backlog, chain verification sample. |

# 20. Plugin Architecture

| Plugin type | Interface (simplified) | Runs where | Isolation |
| --- | --- | --- | --- |
| Detector | `test(req, ctx): boolean` (sync, pure) | SDK and Hub, in the decision path | 1 ms budget; exceptions → `on_error` |
| Notifier | `send(approval): ProviderRef`, `update(ref, outcome)`, `listen(onDecision)` | Hub worker thread | Worker restart on crash |
| Exporter | `export(batch): void` | Hub worker thread | Outbox retries, breaker |
| Adapter | Framework-specific wrapper returning guarded tools | Agent process | Same as SDK |
| Pack | Policy YAML + tests + docs | Compiled into policy | Validated like any policy |
| Suite | Attack or regression cases | Test runner | Runs in replay only |

Plugins are npm or PyPI packages named `agentkeel-plugin-<name>` (community) or `@agentkeel/plugin-<name>` (official), declared in `agentkeel.yaml` with a pinned version and a `capabilities` list (e.g. `network: [api.slack.com]`). The Hub warns when a plugin asks for capabilities beyond its type. The plugin API is versioned (`apiVersion: 1`) separately from AgentKeel releases; it is a preview in v0.2 and stable at v1.0.

# 21. Dashboard Architecture

| Aspect | Design |
| --- | --- |
| Stack | Vite + React + TypeScript, TanStack Router and Query, Tailwind CSS with shadcn/ui (Radix primitives) for accessible components. |
| Delivery | Built to static files and bundled inside the CLI package; served by the Hub at `http://127.0.0.1:7471`. No CDN, no external fonts (Inter and JetBrains Mono self-hosted). |
| Data | Only API v1. TanStack Query caches; SSE updates the activity feed and approvals inbox in real time; ETags for trace pages. |
| State | URL holds filters (shareable links); no global store beyond Query cache. |
| Performance | Virtualised lists for feeds over 1,000 rows; code-split per screen; initial JS < 250 KB gzip. |
| Accessibility | WCAG 2.1 AA: keyboard paths, focus rings, text labels with colour badges, reduced-motion support; axe checks in Playwright. |
| Themes | Light and dark using the AgentKeel brand tokens; same design tokens power the docs site. |
| Server mode | Same SPA; login screen appears when the Hub runs with auth enabled. |

# 22. Configuration Reference

## 22.1 Files and directories

| Path | Committed to Git? | Contents |
| --- | --- | --- |
| `agentkeel.yaml` | Yes | Policy, approvers, limits, redaction, plugins, telemetry choice |
| `agentkeel/cases/*.yaml` | Yes | Learned cases (Flow 7) |
| `agentkeel.test.ts` / `agentkeel_test.py` | Yes | Agent-mode replay entry point |
| `.agentkeel/agentkeel.db` | No (gitignored) | Local store (SQLite WAL) |
| `.agentkeel/spool/` | No | Events waiting for the Hub |
| `.agentkeel/run/hub.json`, `hub.sock` | No | Hub discovery and socket |
| `~/.agentkeel/token`, `~/.agentkeel/keys/` | Never | Local API token, signing keys |

## 22.2 Environment variables

| Variable | Default | Effect |
| --- | --- | --- |
| `AGENTKEEL_HUB_URL` | auto-discover | Use a specific Hub (e.g. server mode `https://…`) |
| `AGENTKEEL_API_KEY` | — | Server-mode API key |
| `AGENTKEEL_AUTOSTART` | `1` | Let the SDK start the Hub automatically |
| `AGENTKEEL_MODE` | `live` | `shadow` for candidate versions |
| `AGENTKEEL_TELEMETRY` | from config (`false`) | `0` forces off everywhere |
| `AGENTKEEL_LOG` | `info` | Log level for SDK and Hub |
| `AGENTKEEL_DATA_DIR` | `.agentkeel` | Where local data lives |

# 23. Open Questions and Appendix

| # | Question | Decide by |
| --- | --- | --- |
| TQ1 | CEL subset: adopt an existing JavaScript CEL implementation or write a minimal evaluator? Decide after a 2-day spike on size, speed and safety. | Jan 2027 |
| TQ2 | Windows named-pipe peer-credential checks: feasible from Node, or token-only on Windows? | v0.1 build |
| TQ3 | Should the Hub support multiple projects in one process for monorepos with several agents? | v0.2 |
| TQ4 | Transparency-log anchoring of checkpoints (e.g. Sigstore Rekor) as an optional exporter? | v0.3 |

## 23.1 Traceability (PRD → TDD)

| PRD item | TDD section |
| --- | --- |
| F-01, F-19 SDKs | §8, §5 |
| F-02 MCP proxy, F-18 Claude Code | §13 |
| F-03 Policy engine | §7 |
| F-04 Approvals | §9, Flow 4 |
| F-05 Kill, limits | §10, Flow 6 |
| F-07, F-08 Events, audit | §11, §15, Event Schema Spec |
| F-09 Dashboard | §21 |
| F-10 Exporters | §11, §20 |
| F-11 to F-16 Learn, Test, Shadow | §12, Flows 7–9 |
| F-20 Plugins | §20 |
| F-21 Server mode | §15.4, §16, Flow 10 |
| NFR-01 to NFR-18 | §16, §17, §18, §19 |

## 23.2 Glossary

| Term | Meaning |
| --- | --- |
| Hexagonal architecture | Core logic talks to the outside world only through interfaces (ports) implemented by adapters. |
| Projection | A read-optimised table derived from events, rebuildable at any time. |
| Transactional outbox | Writing "messages to send" in the same database transaction as the business change, sent later by a worker. |
| Compare-and-set | Update that only succeeds if the row still has the expected version. |
| WAL | Write-ahead logging; lets SQLite readers and one writer work at the same time. |
| UDS | Unix domain socket; local inter-process communication protected by file permissions. |
| JCS | JSON Canonicalization Scheme (RFC 8785): one exact byte form for a JSON value, used for hashing. |

## 23.3 Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Lead maintainer and architect | Ashutosh Kumar Rao | Pending review |  |
