#!/usr/bin/env bash
# Creates or updates the AgentKeel label set (SDLC Strategy, Appendix 22.1).
# Usage: gh auth login && ./scripts/sync-labels.sh
set -euo pipefail
REPO="${REPO:-agentkeel/agentkeel}"
label() { gh label create "$1" --repo "$REPO" --color "$2" --description "$3" --force; }

# type
label "type/bug"        "d73a4a" "Something is not working"
label "type/feature"    "a2eeef" "New capability"
label "type/docs"       "0075ca" "Documentation"
label "type/chore"      "ededed" "Maintenance"
label "type/security"   "b60205" "Security hardening (not vulnerabilities)"
label "type/rfc"        "5319e7" "Design proposal"
# area
for a in policy core spec sdk hub cli dashboard mcp notifiers python packs docs ci; do
  label "area/$a" "c5def5" "Area: $a"
done
# priority
label "priority/critical" "b60205" "Drop everything"
label "priority/high"     "d93f0b" "Next up"
label "priority/medium"   "fbca04" "Planned"
label "priority/low"      "0e8a16" "Nice to have"
# size
label "size/S" "e6e6e6" "Less than a day"
label "size/M" "cccccc" "One to three days"
label "size/L" "999999" "Needs shaping or splitting"
# status
label "needs-triage" "fef2c0" "Waiting for a maintainer"
label "needs-info"   "fef2c0" "Waiting for the author"
label "accepted"     "0e8a16" "Agreed and ready to work on"
label "blocked"      "000000" "Blocked by something else"
label "wontfix"      "ffffff" "Will not be worked on"
label "duplicate"    "cfd3d7" "Already reported"
label "stale"        "eeeeee" "No recent activity"
# community and release
label "good first issue" "7057ff" "Great for newcomers"
label "help wanted"      "008672" "Extra attention welcome"
label "design-partner"   "1d76db" "From a design partner"
label "dependencies"     "0366d6" "Dependency updates"
label "breaking-change"  "b60205" "Changes public behaviour"
echo "Labels synced for $REPO"
