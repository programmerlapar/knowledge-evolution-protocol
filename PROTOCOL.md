# Knowledge Evolution Protocol (KEP)

A portable **brain-first contract** for AI coding agents (opencode, OpenClaw, Claude, etc.).
It gives the agent a persistent, searchable `brain/` of durable knowledge, a mandatory
**retrieve-before** step, and a disciplined **capture-after** workflow — so it keeps learning
about projects, issues, debugging, and patterns across sessions.

## The Contract (summary)

1. **Retrieve before.** Before any non-trivial coding / debugging / research task, search the
   brain for the topic. If a hit exists, read and apply it before acting.
2. **Capture after.** Whenever a durable fact is learned (a fix, a pattern, a gotcha, project
   knowledge), write it to the brain and reindex.
3. **Announce.** Emit `[brain]` markers so a human can verify the brain is actually being used.
4. **Respect guardrails.** Never store secrets; summarize, don't dump transcripts; keep
   retrievals small and fast.

> A skill alone cannot *guarantee* retrieval (skills load only on heuristic match). The
> guaranteed, always-on layer is an `AGENTS.md` loaded every session (or a plugin hooking
> `tool.execute`). This repo ships both the portable skill and the AGENTS.md contract.

## Directory layout

The brain is a folder of small Markdown files organized by namespace:

```
brain/
├── concepts/                     # how things work
│   └── [domain]/[concept-name].md
├── issues/                       # MANDATORY — bugs/issues & their fixes
│   └── [domain]/[issue-name].md
├── patterns/                     # reusable solutions
│   └── [domain]/[name].md
├── references/                   # quick-reference material
│   └── [topic]/[name].md
├── toolbox/                      # tools actually used
│   └── [category]/[tool-name].md
├── memory/YYYY-MM-DD.md          # session journals
└── _access.log                   # (optional) plugin access log, gitignored
```

Domains are grouped by topic: `agents`, `opencode`, `openclaw`, `flowtive`, `programming`,
`devops`, `data`, `security`, `productivity`, etc.

## Brain root override

The brain root defaults to `~/.config/opencode/brain/` (collection `opencode`). Set the
`KEP_BRAIN_DIR` environment variable to point at a different brain — useful for tests,
sandboxes, or multiple knowledge bases. If you override it, make sure the `opencode` QMD
collection points at that directory too (`qmd collection add "$KEP_BRAIN_DIR" --name opencode`).

## File format

Every brain file **must** have YAML frontmatter:

```yaml
---
topic: <canonical-topic-name>
queries: [query1, query2, query3]
tags: [tag1, tag2, tag3]
updated: YYYY-MM-DD
---

Body...
```

## Search backend

KEP uses [QMD](https://qmd.fun) (Quick Markdown Search) as the indexing/search engine.
It provides BM25 keyword search, local vector embeddings, and a stdio **MCP server**
(`qmd mcp`) that agents can register as a tool. Install: `npm i -g qmd`.

Configure collections in `~/.config/qmd/index.yml` or via:

```bash
qmd collection add <name> <path-to-brain>
qmd update      # rescan filesystem
qmd embed       # generate vector embeddings
```

## Retrieval workflow — BEFORE every task

Run these in order:

1. `search <term>` — exact keyword (BM25). Guarantees exact-term recall (names, commands, errors).
2. `vsearch <term>` — semantic (vector) when the topic is described in words.
3. `query <term>` — hybrid (auto-expansion + rerank) when precision matters and latency is OK.
4. Direct fallback: `ls brain/*<keyword>*.md` + read the file.

Read only the top 1–3 hits. Cap tokens and latency.

## Capture workflow — WHEN you learn something durable

1. Search the brain first to avoid duplicates.
2. Existing file found? **Patch** the relevant section (add a dated subsection, or correct and bump `updated`).
3. New topic? Create `brain/<namespace>/<domain>/<name>.md` with frontmatter.
4. **Reindex after every write** (update rescans; embed alone misses new files):
   ```bash
   qmd update
   qmd embed
   ```
5. Announce: `[brain] captured <namespace>/<topic>.md (reindexed)`.

## Mandatory issue capture

Any resolved issue / bug / debugging breakthrough MUST be recorded before the task is
considered done. This is **non-negotiable** — not a judgment call:

1. Write to `brain/issues/<domain>/<name>.md`.
2. Frontmatter `queries` MUST include the **exact error string**, the **symptom**, and the
   **fix terms** so the same error is found verbatim next time.
3. Body MUST contain: symptom, exact error, root cause, fix steps, `updated` date.
4. Reindex and announce as above.

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

At the end of a significant session, append/update `memory/YYYY-MM-DD.md` summarizing
decisions made, new facts captured, and issues fixed — catching anything missed mid-task.

## Announcement markers

To let a human verify the brain is active, emit these inline:

```
[brain] searched "<topic>" → 3 hits
[brain] applied references/opencode/foo.md
[brain] captured patterns/programming/bar.md (reindexed)
```

## Do NOT capture

- Secrets, tokens, passwords, private keys, raw credentials.
- One-off banter with no future value.
- Raw transcript dumps — summarize instead.

## Verification

The `_access.log` file (written by the optional v2 plugin) records every brain access so
retrieval is provable, not just visible in the transcript.