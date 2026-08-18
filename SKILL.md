---
name: knowledge-evolution-protocol
description: "KEP — brain-first retrieval & capture. Use before any non-trivial coding, debugging, or research task: search the brain for prior knowledge first, then capture durable facts (fixes, patterns, gotchas) after learning them. Triggers on 'check the brain', 'remember', 'what do we know about', project/issue/debug context, and any task where prior knowledge would help."
---

# Knowledge Evolution Protocol (KEP)

Mandatory **retrieve-before** and **capture-after** workflow using a persistent, searchable
`brain/` indexed by QMD.

## Brain location

- **Primary:** `<brain-root>` = `${KEP_BRAIN_DIR:-~/.config/opencode/brain/}` (collection:
  `opencode`). If `KEP_BRAIN_DIR` is set, use it — check with `echo "$KEP_BRAIN_DIR"`.
- **Secondary (auto-detected):** `~/.openclaw/workspace/brain` if present (collection:
  `openclaw`). Search it too; it may hold older shared knowledge.

## File format (every brain file)

```yaml
---
topic: <canonical-topic-name>
queries: [query1, query2, query3]
tags: [tag1, tag2, tag3]
updated: YYYY-MM-DD
---
```

## Retrieval workflow — BEFORE every task

Run before any non-trivial coding / debugging / research. Announce the result inline.

1. `search "<topic>"` (BM25 — exact terms, names, commands, errors). Fall back to:
2. `vsearch "<topic>"` (semantic — described-in-words topics).
3. `query "<topic>"` (hybrid — expansion + rerank, when precision matters over latency).
4. Direct: `ls ~/.config/opencode/brain/*<keyword>*.md` then read.

Read only the **top 1–3 hits**. Announce:

```
[brain] searched "<topic>" → N hits
```

If a hit is used, announce it and read/apply:

```
[brain] applied <namespace>/<domain>/<name>.md
```

If the top result is a weak semantic match for an exact term (name/command/error), drop to
`search` (BM25) immediately — it guarantees exact recall.

## Capture workflow — WHEN you learn something durable

Announce at the start:

```
[brain] capturing <namespace>/<topic>.md
```

1. Search the brain first to avoid duplicates.
2. Existing file found → **patch** the relevant section (dated subsection, or correct + bump
   `updated`).
3. New topic → create `brain/<namespace>/<domain>/<name>.md` with frontmatter.
4. **Reindex after every write** (update rescans the FS; embed alone misses new files):
   ```bash
   qmd update -c opencode
   qmd embed -c opencode
   ```
   If the `openclaw` collection exists and you edited it, run with `-c openclaw` too.
5. Announce:
   ```
   [brain] captured <namespace>/<topic>.md (reindexed)
   ```

## Mandatory issue capture — REQUIRED

Any resolved issue / bug / debugging breakthrough MUST be recorded **before the task is
considered done**. This is non-negotiable, not a judgment call.

1. Write to `<brain-root>/issues/<domain>/<name>.md`.
2. Frontmatter `queries` MUST include the **exact error string**, the **symptom**, and the
   **fix terms** so the same error is found verbatim next time.
3. Body MUST contain: symptom, exact error, root cause, fix steps, `updated` date.
4. Reindex and announce as in the capture workflow above.

```yaml
---
topic: <issue-name>
queries: ["<exact error string>", "<symptom>", "<fix keyword>"]
tags: [issue, <domain>]
updated: YYYY-MM-DD
---
# Symptom
# Exact error
# Root cause
# Fix steps
```

## Session sweep

At the end of a significant session, append/update `<brain-root>/memory/YYYY-MM-DD.md` with
decisions made, new facts captured, and issues fixed — catching anything missed mid-task.

## Do NOT capture

- Secrets, tokens, passwords, private keys, credentials.
- One-off banter with no future value.
- Raw transcript dumps — summarize instead.