# Knowledge Evolution Protocol (KEP)

A portable **brain-first contract** for AI coding agents. Gives the agent a persistent,
searchable `brain/` of durable knowledge plus a mandatory **retrieve-before** step and a
**capture-after** workflow, so it keeps learning about projects, issues, debugging, and
patterns across sessions — in every project.

## What it does

- **Retrieve before** any non-trivial task: search the brain for prior knowledge and apply it.
- **Capture after** learning a durable fact (fix, pattern, gotcha, project knowledge).
- **Announce** via `[brain]` markers so a human can verify it's actually being used.
- **Guardrails**: never store secrets; summarize, don't dump transcripts; keep retrievals fast.

## How it works

- Brain = a folder of small Markdown files with YAML frontmatter, organized by namespace
  (`concepts`, `patterns`, `references`, `toolbox`, `memory`).
- Indexing/search = [QMD](https://qmd.fun) (`qmd search` BM25, `qmd vsearch` semantic,
  `qmd query` hybrid). QMD also exposes a stdio **MCP server** (`qmd mcp`) that agents
  register as a native search tool.
- Enforcement = an `AGENTS.md` contract loaded every session (a skill alone can't guarantee
  retrieval; `AGENTS.md` is the always-on layer). A v2 plugin can add hard telemetry via
  `tool.execute` + `brain/_access.log`.

## Install

### Windows PowerShell

Prerequisites: [Node.js](https://nodejs.org/) with `npm`, and OpenCode. From PowerShell:

```powershell
git clone https://github.com/programmerlapar/knowledge-evolution-protocol.git
Set-Location knowledge-evolution-protocol
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

The PowerShell installer installs `qmd` with npm when needed, creates the global
`$HOME\.config\opencode` brain, installs the skill and `/remember` command, and registers
the Windows `qmd.cmd mcp` command in `opencode.json`. It does not require Git Bash or Python.

If PowerShell blocks script execution, `-ExecutionPolicy Bypass` applies only to this process.
Set `KEP_OPENCODE_DIR`, `KEP_BRAIN_DIR`, `KEP_QMD_CMD`, or `KEP_NO_INSTALL=1` in the PowerShell
environment before running the script when you need the same overrides as the Bash installer.

Then restart OpenCode.

### macOS

Prerequisites: [Git](https://git-scm.com/), [Node.js 22 or newer](https://nodejs.org/) with
`npm`, and OpenCode. From Terminal, run these commands from the directory where you keep
your tools:

```bash
git clone https://github.com/programmerlapar/knowledge-evolution-protocol.git
cd knowledge-evolution-protocol
bash scripts/install.sh
```

The installer installs QMD globally with npm when needed. It creates the brain at
`~/.config/opencode/brain`, installs the KEP skill and `/remember` command, and registers
the QMD MCP server in your global OpenCode config. It is safe to run again.

If you already have `~/.config/opencode/opencode.jsonc` with comments or trailing commas,
the installer may warn that it cannot parse the file as strict JSON. Add this entry manually
under the top-level `mcp` object, preserving any existing MCP entries:

```json
"qmd": { "type": "local", "command": ["qmd", "mcp"], "enabled": true }
```

Restart OpenCode after installation. Verify the setup with:

```bash
qmd collection list
grep -n '"qmd"' ~/.config/opencode/opencode.jsonc 2>/dev/null || \
grep -n '"qmd"' ~/.config/opencode/opencode.json
```

### Linux or Git Bash

```bash
git clone https://github.com/programmerlapar/knowledge-evolution-protocol.git
cd knowledge-evolution-protocol
bash scripts/install.sh
```

The installer (idempotent, safe) will:

1. Install `qmd` if missing (`npm i -g qmd`).
2. Create `~/.config/opencode/brain/` and register it as the `opencode` QMD collection.
3. **Auto-detect** an existing OpenClaw brain (`~/.openclaw/workspace/brain`) and register it
   as an `openclaw` secondary collection (skipped silently if absent).
4. Write the global `~/.config/opencode/AGENTS.md` contract (merged, never clobbers).
5. Install the `knowledge-evolution-protocol` skill and the `/remember` command.
6. Register the `qmd` MCP server in `opencode.json(c)` (with a backup).

Then **restart opencode**.

> Machine-specific: if your qmd needs a wrapper (e.g. a specific Node version or CPU-forced
> embeddings), set `KEP_USE_WRAPPER=1` to use `~/.openclaw/workspace/scripts/qmd-safe.sh`, or
> point `KEP_QMD_CMD` at your own wrapper. The default is plain `qmd` for portability.

## Usage

- **Automatic.** The `AGENTS.md` contract triggers retrieval and capture on non-trivial tasks.
- **Manual capture:** `/remember <topic>: <what you learned>`.

Verify it's working by grepping sessions for `[brain]` markers:

```
[brain] searched "<topic>" → 3 hits
[brain] applied references/opencode/foo.md
[brain] captured patterns/programming/bar.md (reindexed)
```

## Structure

```
PROTOCOL.md              # full contract spec
SKILL.md                 # portable agent skill (retrieval + capture + indexing)
AGENTS.md.template       # always-on contract, installed to ~/.config/opencode/AGENTS.md
command/remember.md      # /remember capture command
scripts/install.sh       # one-shot idempotent installer
scripts/install.ps1      # native Windows PowerShell installer
tests/                   # test suite (Tier 1-2 plumbing; Tier 3 e2e gated by RUN_E2E=1)
brain/                   # empty namespace scaffold (your data lives in ~/.config/opencode/brain)
```

## Testing

```bash
bash tests/run.sh              # Tier 1 + 2 (plumbing + contract) — no LLM needed
RUN_E2E=1 bash tests/run.sh     # + Tier 3 real opencode session (requires model API, costs tokens)
```

- Tier 1 verifies install, qmd search/vsearch/query recall, capture→reindex, and the MCP
  handshake against a scratch brain.
- Tier 2 verifies the installed contract contains the mandatory sections (regression guard).
- Tier 3 runs a real headless opencode session on a fixture Node project, asserting
  `[brain] searched`/`[brain] applied` retrieval and that a resolved issue is captured and
  reused on recurrence. Tests use `KEP_BRAIN_DIR` + a scratch brain so your real knowledge
  is never touched.

## Brain root override

Set `KEP_BRAIN_DIR` to point the brain at another directory (tests, sandboxes, multiple KBs).
Keep the `opencode` QMD collection pointed at it too.

## License

MIT
