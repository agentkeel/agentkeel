# Security Policy

AgentKeel sits in front of AI agents that can change real systems, so we take
security reports seriously and handle them quickly and privately.

## Reporting a vulnerability

**Please do not open a public issue.**

Use GitHub's private reporting:
**[Report a vulnerability](https://github.com/agentkeel/agentkeel/security/advisories/new)**
(Security tab → "Report a vulnerability"). No email is needed.

Please include:

- affected package(s) and version(s)
- a description of the issue and what an attacker could make an agent do
- steps to reproduce or a proof of concept
- any suggested fix

## What to expect

| Step | Target time |
|------|-------------|
| Acknowledgement | within 48 hours |
| Triage and severity (CVSS 4.0) | within 5 days |
| Fix for critical severity | within 14 days |
| Fix for high severity | within 30 days |
| Medium / low | next regular release |

We fix the issue in a private fork, release patched versions, then publish a
GitHub Security Advisory and request a CVE. Reporters are credited unless they
prefer otherwise.

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest minor (0.x) | ✅ all fixes |
| Previous minor | ✅ security fixes for 3 months after the next minor |
| Older | ❌ |

From 1.0, the previous minor receives security fixes for 6 months.

## Scope

In scope: all packages in this repository (SDKs, Hub, CLI, MCP proxy,
dashboard, policy packs) and the release pipeline.

Examples of high-impact issues:

- a way to make a blocked action execute (policy bypass)
- forging or replaying an approval
- secrets stored or exported without redaction
- tampering with the audit log without `agentkeel verify` noticing
- remote access to the local Hub or dashboard (e.g. DNS rebinding)

Out of scope: prompt injection of a model itself (AgentKeel governs the
resulting **actions**), vulnerabilities in third-party agents or frameworks,
and issues requiring a fully compromised machine.

## Safe harbour

We will not take action against good-faith research that respects user privacy,
avoids service disruption and gives us reasonable time to fix before disclosure.
