---
description: "Capture a durable fact into the knowledge brain (KEP). Usage: /remember <topic>: <what you learned>"
---

Record this into the brain. If $ARGUMENTS is empty, ask me what I learned and where it belongs.

Capture workflow:
1. Search the brain first (`search "<topic>"`) to avoid duplicates.
2. If a file exists for the topic: READ it, patch the relevant section, bump `updated`.
   Else create `~/.config/opencode/brain/<namespace>/<domain>/<name>.md` with frontmatter:
   `topic`, `queries`, `tags`, `updated`.
3. Pick the right namespace: issues (bugs & fixes — REQUIRED for resolved issues),
   concepts (how things work), patterns (reusable solutions), references (quick reference),
   toolbox (tools actually used), memory (session notes).
   For a resolved issue/bug, capture the exact error string, symptom, root cause, and fix in
   both frontmatter `queries` and the body.
4. Announce: `[brain] capturing <namespace>/<topic>.md`
5. Reindex:
   ```
   qmd update -c opencode
   qmd embed -c opencode
   ```
6. Announce: `[brain] captured <namespace>/<topic>.md (reindexed)`

Guardrails: never store secrets/credentials; summarize, don't dump transcripts; one-off
banter with no future value → skip.