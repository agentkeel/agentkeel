# AgentKeel Event Schema Specification 1.0-draft

> Markdown copy of the Word document for use by contributors and Claude Code. The Word/PDF version is the formatted original; diagrams are in `flows/`.

# 1. Introduction and Conformance

The **AgentKeel Event Schema** ("ES") is an open format for recording the actions of AI agents: what an agent tried to do, which policy decided, which human approved, what the tool returned, and how mistakes became tests. Every AgentKeel feature reads and writes this one format (BR-06, BR-22), and anyone can produce or consume it without using AgentKeel at all.

ES builds on **CloudEvents 1.0** (a CNCF graduated specification) for the envelope, **JSON Schema 2020-12** for validation, **RFC 8785 (JCS)** for canonical hashing and **RFC 3339** for time. It adds a small set of extension attributes and typed payloads for agent actions.

## 1.1 Status

| Version | Status | Stability promise |
| --- | --- | --- |
| 1.0-draft | This document. Ships with AgentKeel v0.1 (March 2027). | May change between minor releases of AgentKeel 0.x, with migration notes. |
| 1.0 | Frozen at AgentKeel v1.0 (Q4 2027). | Only backward-compatible additions in 1.x (Section 9). |

## 1.2 Conformance language

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT** and **MAY** are to be interpreted as described in RFC 2119 and RFC 8174 when, and only when, they appear in capitals.

| Role | Definition | Key obligations |
| --- | --- | --- |
| Producer | Software that creates events (SDKs, proxies, hooks, third-party agents). | Valid envelope and payload; redaction before emitting; unique ids. |
| Collector | Software that stores events and builds the chain (the Keel Hub). | Validate, deduplicate, assign `akseq`, `akprevhash`, `akhash`; never modify `data`. |
| Consumer | Software that reads events (dashboard, exporters, analytics, auditors). | Ignore unknown attributes, types and fields; verify chain when integrity matters. |

# 2. Design Goals

| Goal | How ES achieves it |
| --- | --- |
| Neutral | No dependency on any model provider, framework or AgentKeel component. CloudEvents envelope is understood by existing tools. |
| Complete story | One trace can show input reference, request, decision, approval, execution, result, cost and latency. |
| Safe by default | Payloads carry redacted values only; a standard redaction marker shows what was removed without revealing it. |
| Verifiable | Hash chain over a canonical byte form; signed checkpoints. |
| Evolvable | Strict additive-change rules, explicit `dataschema` per event, readers that ignore the unknown. |
| Cheap to produce | Small required set; most fields optional; JSON Lines friendly; batchable. |
| Replayable | Requests and results are recorded in a form the replay runner can use as test input and tool doubles. |

# 3. Core Concepts

Flow 1 shows how the concepts nest. Each concept has a TypeID identifier (a type prefix plus a base32-encoded UUIDv7).

| Concept | ID prefix | Definition |
| --- | --- | --- |
| Project | — (slug) | A unit of configuration: one policy file, one hash chain. Usually one repository or one deployed agent system. |
| Session | `ses_` | One run of an agent process or one conversation. Has an agent name, version and mode (`live` or `shadow`). |
| Trace | `trc_` | One task or turn inside a session, e.g. handling one support ticket. MAY carry a W3C trace id. |
| Action | `act_` | One attempt to call one tool. All events about that attempt share the action id. |
| Approval | `apr_` | A request for a human decision about one action. |
| Event | `evt_` | An immutable fact about any of the above, at one point in time. |
| Input | free string | `input_id`: an id for the external input (ticket id, message id) used to pair live and shadow traces. |

# 4. Event Envelope

Every event is a CloudEvents 1.0 event in **structured JSON mode**. The tables list the attributes used and the rules ES adds.

## 4.1 CloudEvents attributes

| Attribute | Required | ES rule | Example |
| --- | --- | --- | --- |
| `specversion` | MUST | Always `"1.0"`. | `1.0` |
| `id` | MUST | TypeID with prefix `evt_`; unique per producer; collectors dedupe on it. | `evt_01jq3v8k2z…` |
| `source` | MUST | URI-reference naming the producer instance: `agentkeel://<project>/<component>/<instance>`. | `agentkeel://support-bot/sdk/host-7f3a` |
| `type` | MUST | Reverse-DNS `dev.agentkeel.<area>.<event>`; catalogue in Section 6. | `dev.agentkeel.action.requested` |
| `time` | MUST | RFC 3339 UTC with milliseconds, producer clock. | `2027-04-02T10:15:00.123Z` |
| `subject` | SHOULD | Main object id: action, approval, case or run. | `act_01jq…` |
| `datacontenttype` | SHOULD | `application/json`. |  |
| `dataschema` | MUST | URI of the JSON Schema for `data`, including the ES major version. | `https://agentkeel.github.io/schemas/v1/action.requested.json` |
| `data` | MUST | Typed payload (Section 7). Field names snake_case. | {…} |

## 4.2 AgentKeel extension attributes

CloudEvents extension names must be lowercase alphanumeric. ES defines these, all prefixed `ak` to avoid collisions:

| Extension | Set by | Required | Meaning |
| --- | --- | --- | --- |
| `akspec` | Producer | MUST | ES version of this event, e.g. `1.0`. |
| `akproject` | Producer | MUST | Project slug. |
| `aksession` | Producer | MUST* | Session id (`ses_…`). *Not for project-level events such as `policy.loaded`. |
| `aktrace` | Producer | SHOULD | Trace id (`trc_…`). |
| `akaction` | Producer | MUST for action events | Action id (`act_…`). |
| `akmode` | Producer | SHOULD | `live` or `shadow`. Default `live`. |
| `traceparent` | Producer | MAY | W3C Trace Context, as defined by the CloudEvents distributed tracing extension. |
| `akseq` | Collector | MUST after ingest | Gapless sequence number within the project chain. |
| `akingested` | Collector | MUST after ingest | Collector time (RFC 3339). |
| `akprevhash` | Collector | MUST after ingest | Lowercase hex SHA-256 of the previous event in the chain. |
| `akhash` | Collector | MUST after ingest | Lowercase hex SHA-256 of this event (Section 8). |

Producers **MUST NOT** set `akseq`, `akingested`, `akprevhash` or `akhash`; collectors **MUST** reject or overwrite them.

## 4.3 Example envelope

*Example 4.1  An action.requested event as emitted by a producer*

```text
{
  "specversion": "1.0",
  "id": "evt_01jq3v8k2zf9x7m4n6p5r0s1t2",
  "source": "agentkeel://support-bot/sdk/host-7f3a",
  "type": "dev.agentkeel.action.requested",
  "time": "2027-04-02T10:15:00.123Z",
  "subject": "act_01jq3v8k30a1b2c3d4e5f6g7h8",
  "datacontenttype": "application/json",
  "dataschema": "https://agentkeel.github.io/schemas/v1/action.requested.json",
  "akspec": "1.0", "akproject": "support-bot", "akmode": "live",
  "aksession": "ses_01jq3v7z9y8x7w6v5t4s3r2q1p",
  "aktrace": "trc_01jq3v8a1b2c3d4e5f6g7h8j9k",
  "akaction": "act_01jq3v8k30a1b2c3d4e5f6g7h8",
  "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "data": {
    "tool": "refund",
    "args": { "order_id": "[REDACTED:id:9a1b7c2e]", "amount": 1200, "currency": "INR" },
    "agent": { "name": "support-bot", "version": "1.4.0" },
    "env": "prod", "input_id": "ticket-88213"
  }
}
```

# 5. Common Data Types

| Type | Format | Notes |
| --- | --- | --- |
| Timestamp | RFC 3339 string, UTC, millisecond precision | Example `2027-04-02T10:15:00.123Z`. |
| Duration | Integer milliseconds (`*_ms`) or microseconds (`*_us`) | Name suffix states the unit. |
| Money | `{ "amount_minor": 120000, "currency": "INR" }` | Integer minor units + ISO 4217 code. Floats MUST NOT be used for money. |
| Cost | `{ "usd_micros": 1530 }` or money object | Model or API cost when the producer knows it. |
| Agent | `{ "name": string, "version"?: string, "framework"?: string }` | Name stable across versions. |
| Actor | `{ "kind": "user"\|"service"\|"agent", "id": string, "via"?: string }` | Ids are channel-qualified, e.g. `slack:U04ABC`, `telegram:5512`, `cli:ashutosh`. |
| Rule ref | `{ "id": string, "effect": "allow"\|"ask"\|"block", "pack"?: string }` | Pack name with major version when from a pack. |
| Redaction marker | `"[REDACTED:<kind>:<hmac8>]"` | Section 10. |
| Truncation marker | `{ "_truncated": true, "original_bytes": n, "sha256": hex }` | Replaces a value too large to store. |
| Error | `{ "code": "AK-1203", "message": string, "retryable": boolean }` | Codes from the AgentKeel error catalogue. |

# 6. Event Type Catalogue

All types use the prefix `dev.agentkeel.`. The prefix is omitted below for readability.

| Type | Subject | Emitted when | Producer |
| --- | --- | --- | --- |
| `session.started` / `session.ended` | ses | Agent run begins / ends | SDK, proxy |
| `action.requested` | act | Agent attempts a tool call | SDK, proxy, hook |
| `policy.decided` | act | Decision made | SDK or Hub |
| `approval.requested` | apr | Approval created | Hub |
| `approval.notified` | apr | Message delivered on a channel | Hub |
| `approval.decided` | apr | Approved or rejected by a person | Hub |
| `approval.expired` / `approval.cancelled` | apr | Timeout / cancel | Hub |
| `approval.refused` | apr | Unauthorised decision attempt | Hub |
| `action.executed` / `action.denied` | act | Tool called / not called | SDK, proxy, hook |
| `action.result` | act | Tool returned or threw | SDK, proxy, hook |
| `limit.breached` | act | Budget, rate or loop limit hit | SDK or Hub |
| `kill.activated` / `kill.released` | kil | Kill switch change | Hub |
| `policy.loaded` / `policy.invalid` | project | Policy compiled / rejected | SDK, Hub |
| `case.created` / `case.updated` | cas | Learn stage | Hub, CLI |
| `test.run` / `test.case_result` | run | Test stage | Test runner |
| `shadow.paired` / `shadow.compared` | shp | Shadow stage | Hub |
| `engine.error` | act or project | Internal failure handled by `on_error` | Any |
| `chain.checkpoint` | project | Signed checkpoint written | Hub |
| `retention.pruned` / `data.purged` | project | Data removed by retention or request | Hub |
| `inventory.tools` | ses | MCP `tools/list` observed | Proxy |

# 7. Payload Definitions

This section defines the `data` object of the most important types. "Req." means required (R) or optional (O). Unknown fields MUST be ignored by consumers. The full set of JSON Schemas is published at `https://agentkeel.github.io/schemas/v1/` and in the `@agentkeel/spec` package.

## 7.1 action.requested

| Field | Type | Req. | Description |
| --- | --- | --- | --- |
| `tool` | string | R | Tool name as the agent sees it; MCP tools as `<server>.<tool>`. |
| `args` | object | R | Arguments after redaction. Large values replaced by truncation markers. |
| `agent` | Agent | R | Name and version of the agent making the call. |
| `env` | string | O | Environment label (`dev`, `staging`, `prod`). |
| `input_id` | string | O | External input reference for shadow pairing. |
| `tags` | map<string,string> | O | User labels (customer tier, region). |
| `side_effects` | `none` \| `unknown` \| `write` | O | Declared by tool options; used by shadow mode. |

## 7.2 policy.decided

| Field | Type | Req. | Description |
| --- | --- | --- | --- |
| `effect` | `allow` \| `ask` \| `block` | R | Final decision. |
| `source` | `kill` \| `limit` \| `rule` \| `default` \| `on_error` | R | What produced the decision. |
| `winning_rule` | Rule ref | O | Rule that set the effect (absent for default). |
| `matched_rules` | string[] | R | All matched rule ids (may be empty). |
| `reason` | string | O | Human-readable reason shown to agent and approver. |
| `policy_hash` | hex string | R | SHA-256 of the normalised policy used. |
| `eval_us` | integer | R | Evaluation time in microseconds. |
| `approval_id` | string | O | Present when `effect = ask`. |
| `control_stale` | boolean | O | True if the kill/limit snapshot was stale. |

## 7.3 approval.requested and approval.decided

| Field | Type | Req. | Description |
| --- | --- | --- | --- |
| `action_id` | string | R | The action waiting for a decision. |
| `rule_id` | string | R | Rule that asked. |
| `approver_group` | string | R | Group name from the policy. |
| `channels` | string[] | R (requested) | Channels notified (`slack`, `telegram`, `cli`, `dashboard`). |
| `expires_at` | Timestamp | R (requested) | When `on_timeout` applies. |
| `decision` | `approved` \| `rejected` | R (decided) | The human decision. |
| `actor` | Actor | R (decided) | Who decided and through which channel. |
| `comment` | string | O | Optional comment, redacted like args. |
| `version` | integer | R | Approval version after the change. |

## 7.4 action.executed, action.denied, action.result

| Field | Type | Req. | Description |
| --- | --- | --- | --- |
| `decision_event` | string | R (executed/denied) | Id of the `policy.decided` event. |
| `denied_by` | `policy` \| `approval` \| `timeout` \| `kill` \| `limit` \| `shadow` \| `error` | R (denied) | Why the tool was not called. |
| `status` | `ok` \| `error` | R (result) | Outcome of the tool call. |
| `result` | any | O (result) | Redacted, possibly truncated result. |
| `error` | Error | O (result) | Tool error (message redacted). |
| `latency_ms` | integer | R (result) | Tool execution time. |
| `cost` | Cost | O (result) | Cost if known. |
| `response_hash` | hex string | O (result) | SHA-256 of the canonical unredacted result, for replay matching without storing secrets. |

## 7.5 Other payloads (summary)

| Type | Key fields |
| --- | --- |
| `session.started` | `agent`, `mode`, `sdk` (`name`, `version`, `language`), `host` (hashed), `framework` |
| `limit.breached` | `limit_id`, `kind` (`budget`/`rate`/`loop`), `window`, `value`, `max`, `effect` |
| `kill.activated` | `kill_id`, `scope`, `reason`, `actor`; `kill.released` adds `released_by` |
| `policy.loaded` / `policy.invalid` | `policy_hash`, `packs[]`, `rule_count`; invalid adds `errors[]` with `line`, `column`, `message` |
| `case.created` | `case_id`, `fingerprint`, `source_event`, `expected`, `status`, `file` |
| `test.run` | `run_id`, `mode`, `suites[]`, `git_sha`, `totals` (`pass`, `fail`, `flaky`), `status` |
| `test.case_result` | `run_id`, `case_id`, `result`, `repeats`, `actual`, `expected`, `diff` |
| `shadow.paired` / `shadow.compared` | `pair_id`, `input_id`, `live_trace`, `shadow_trace`; compared adds `summary` |
| `engine.error` | `error` (Error), `component`, `applied` (`on_error` effect) |
| `chain.checkpoint` | `seq`, `head_hash`, `key_id`, `signature` (Ed25519, base64url) |
| `retention.pruned` / `data.purged` | `up_to_seq`, `last_pruned_hash`, `count`, `reason`, `actor` |

# 8. Integrity: Hash Chain and Checkpoints

Flow 2 shows the chain. The collector maintains one chain per project.

## 8.1 Hash computation

*Figure 8.1  Chain definition*

```text
canonical(e) = JCS( e without the attributes akseq, akingested, akprevhash, akhash )   // RFC 8785
akhash(e_n)  = hex( SHA-256( bytes(akprevhash(e_n)) || canonical(e_n) ) )
akprevhash(e_1) = "0000…0000" (64 zeros)  for the first event of a project (genesis)
```

- `akseq` starts at 1 and increases by exactly 1; gaps are a verification failure unless covered by a `retention.pruned` or `data.purged` event.
- Because `data` is hashed in canonical form, consumers can re-serialise JSON freely without breaking verification.
- Collectors MUST NOT change `data` after hashing. Corrections are new events, never edits.

## 8.2 Checkpoints

A collector SHOULD write a `chain.checkpoint` event at least every 10,000 events or every hour. The checkpoint signs the string `akcp1|<project>|<seq>|<head_hash>` with the project's Ed25519 key. Copying checkpoints somewhere the agent machine cannot rewrite (a Git repository, object storage, email, a transparency log) turns "tamper-evident" into strong evidence: an attacker would have to rewrite every copy.

## 8.3 Verification algorithm

*Figure 8.2  Verification*

```text
verify(events sorted by akseq, from_checkpoint?):
  prev = from_checkpoint ? checkpoint.head_hash : ZERO64;  expect = (from_checkpoint?.seq ?? 0) + 1
  for e in events:
    if e.akseq != expect and not covered_by_prune(expect, e.akseq): return BROKEN(expect, "gap")
    if e.akprevhash != prev:                                     return BROKEN(e.akseq, "link")
    if sha256(prev || canonical(e)) != e.akhash:                  return BROKEN(e.akseq, "content")
    if e.type == "dev.agentkeel.chain.checkpoint" and not valid_sig(e): return BROKEN(e.akseq, "signature")
    prev = e.akhash; expect = e.akseq + 1
  return VALID(head = prev)
```

# 9. Versioning and Compatibility

| Change | Allowed in 1.x? | Rule |
| --- | --- | --- |
| Add an optional field to a payload | Yes | Consumers ignore unknown fields. |
| Add a new event type | Yes | Consumers ignore unknown types. |
| Add a new enum value | Yes, with care | Consumers MUST handle unknown enum values (treat as "other"). |
| Make an optional field required | No | Needs ES 2.0. |
| Rename or remove a field or type | No | Deprecate in 1.x (still emitted), remove only in 2.0. |
| Change a field's meaning or unit | No | Add a new field with a new name instead. |

- The major version appears in `dataschema` (`/schemas/v1/…`) and `akspec`. A 2.0 collector MUST still read 1.x events.
- Each JSON Schema file has an `$id` and is immutable once published; fixes publish a new minor schema version.
- Deprecations are listed in the spec changelog with the release that will remove them.

# 10. Redaction and Privacy

Events are designed to be safe to store and share inside a team. Producers MUST redact before emitting; collectors SHOULD re-check.

| Rule | Detail |
| --- | --- |
| Key-based | Values of keys matching default or configured patterns (`password`, `secret`, `token`, `api_key`, `authorization`, `*.token`, `cookie`) are replaced. |
| Value-based | Detectors for emails, phone numbers (including Indian formats), payment card numbers (Luhn-checked), JWTs, common cloud and SaaS key formats, private keys. |
| Marker | `[REDACTED:<kind>:<hmac8>]` where `hmac8` is the first 8 hex chars of HMAC-SHA-256(project salt, value). Equal values get equal markers, so replay and analytics can still compare them without seeing them. |
| Truncation | Values over 8 KB (configurable) become truncation markers with the original size and hash. |
| Never in events | Raw secrets, full documents, model prompts (unless the user explicitly opts in per tool with `record_prompt: true`). |
| Deletion | `data.purged` records what was deleted (by session, time or subject id) without containing the deleted data. |

# 11. Transport and File Bindings

| Binding | Format | Use |
| --- | --- | --- |
| HTTP batch | `POST /v1/events:batch` with `application/cloudevents-batch+json` (array of structured events), optional gzip | SDK → Hub; third-party producers |
| HTTP single | CloudEvents HTTP structured mode (`application/cloudevents+json`) | Webhooks and simple producers |
| JSON Lines file | One structured event per line, UTF-8, `.jsonl` (optionally `.jsonl.gz`) | Spool files, exports, archives |
| SSE stream | `event: <type>`, `id: <akseq>`, `data: <event JSON>` | Dashboard, `agentkeel tail`, integrations |
| OTLP | Mapped spans and logs (Section 12) | Export to OpenTelemetry backends |

# 12. Mapping to OpenTelemetry

ES events can be exported as OpenTelemetry spans so they appear next to existing application traces. The mapping uses the OpenTelemetry **GenAI semantic conventions** where they exist (these conventions are still marked as in development, so the exporter pins the convention version it uses) and `agentkeel.*` attributes for the rest.

| ES | OpenTelemetry |
| --- | --- |
| Trace (`aktrace`, `traceparent`) | Trace id from `traceparent` if present; otherwise derived from `aktrace`. |
| Action (`akaction`) | Span named `execute_tool <tool>` with `gen_ai.operation.name = execute_tool`, `gen_ai.tool.name`, `gen_ai.tool.call.id = act_…`. |
| Agent | `gen_ai.agent.name`, `gen_ai.agent.id` (if set), `service.version` = agent version. |
| Session | `gen_ai.conversation.id` = `ses_…`. |
| `policy.decided` | Span event `agentkeel.decision` with `agentkeel.effect`, `agentkeel.rule_id`, `agentkeel.policy_hash`. |
| `approval.*` | Child span `agentkeel.approval` covering wait time; attributes for decision and actor channel. |
| `action.result` | Span status OK/ERROR; `agentkeel.latency_ms`; cost as `agentkeel.cost.usd_micros`. |

# 13. Validation and Conformance Testing

- **Schemas:** one JSON Schema 2020-12 file per event type plus `envelope.json`; all published under `/schemas/v1/`, versioned in Git and the `@agentkeel/spec` package. Python models are generated from the same files.
- **Producer conformance:** a test kit emits nothing but checks producer output: valid envelope, valid payload, no unredacted values from a secrets corpus, unique ids.
- **Collector conformance:** a vector set of event batches with expected `akseq`/`akhash` values, including duplicates, out-of-order client times and prune events.
- **Consumer robustness:** vectors with unknown types, fields and enum values that consumers must accept.
- **Golden files:** canonicalisation test vectors (JSON input → exact JCS bytes → SHA-256) to make independent implementations agree byte for byte.

# 14. Complete Example

One refund that needed approval, as stored after ingest (envelope attributes shortened; `data` complete):

*Example 14.1  One trace, seven events (JSON Lines)*

```text
{"akseq":101,"type":"…action.requested","subject":"act_A","data":{"tool":"refund","args":{"order_id":"[REDACTED:id:9a1b7c2e]","amount":1200,"currency":"INR"},"agent":{"name":"support-bot","version":"1.4.0"},"input_id":"ticket-88213"}}
{"akseq":102,"type":"…policy.decided","subject":"act_A","data":{"effect":"ask","source":"rule","winning_rule":{"id":"big-refunds","effect":"ask"},"matched_rules":["big-refunds"],"reason":"Refunds above 500 need a lead","policy_hash":"5d1c…","eval_us":184,"approval_id":"apr_B"}}
{"akseq":103,"type":"…approval.requested","subject":"apr_B","data":{"action_id":"act_A","rule_id":"big-refunds","approver_group":"leads","channels":["slack","telegram"],"expires_at":"2027-04-02T10:25:00.000Z","version":1}}
{"akseq":104,"type":"…approval.notified","subject":"apr_B","data":{"channel":"slack","provider_ref":"C07…:1712052900.1234"}}
{"akseq":105,"type":"…approval.decided","subject":"apr_B","data":{"action_id":"act_A","decision":"approved","actor":{"kind":"user","id":"slack:U04ABC","via":"slack"},"comment":"Verified on call","version":2}}
{"akseq":106,"type":"…action.executed","subject":"act_A","data":{"decision_event":"evt_…102"}}
{"akseq":107,"type":"…action.result","subject":"act_A","data":{"status":"ok","result":{"refund_id":"rf_7781","state":"processed"},"latency_ms":320,"response_hash":"e3b0…"}}
```

From these seven events a consumer can answer every audit question: what was attempted, which rule asked, who approved and how, when it executed, and what came back. The Learn stage could turn event 105 into a case if the decision had been `rejected`, and the replay runner can use event 107 as a tool double.

# 15. Appendix

## 15.1 JSON Schema excerpt

*Figure 15.1  Schema for policy.decided data*

```text
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://agentkeel.github.io/schemas/v1/policy.decided.json",
  "title": "dev.agentkeel.policy.decided data",
  "type": "object",
  "required": ["effect", "source", "matched_rules", "policy_hash", "eval_us"],
  "properties": {
    "effect":        { "enum": ["allow", "ask", "block"] },
    "source":        { "enum": ["kill", "limit", "rule", "default", "on_error"] },
    "winning_rule":  { "$ref": "common.json#/$defs/rule_ref" },
    "matched_rules": { "type": "array", "items": { "type": "string", "maxLength": 128 } },
    "reason":        { "type": "string", "maxLength": 2000 },
    "policy_hash":   { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "eval_us":       { "type": "integer", "minimum": 0 },
    "approval_id":   { "type": "string", "pattern": "^apr_[0-9a-z]{26}$" },
    "control_stale": { "type": "boolean" }
  },
  "additionalProperties": true
}
```

## 15.2 Glossary

| Term | Meaning |
| --- | --- |
| CloudEvents | CNCF specification for describing events in a common way across services and platforms. |
| TypeID | Type-prefixed, UUIDv7-based, base32-encoded identifier format. |
| JCS | JSON Canonicalization Scheme (RFC 8785). |
| Producer / Collector / Consumer | Roles defined in Section 1.2. |
| Checkpoint | Signed statement of the chain head at a sequence number. |

## 15.3 Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Spec editor and lead maintainer | Ashutosh Kumar Rao | Pending review |  |
