---
name: import-config
description: Import a user's existing coding-agent setup (Claude Code, Cursor, OpenCode, shared AGENTS.md/skills) into this agent. Read this BEFORE importing, migrating, or porting any user config — when the user runs `skydive import`, asks you to "bring my setup over", or mentions CLAUDE.md, .cursor rules, slash commands, or their old coding agent.
---

# Importing a user's coding-agent setup

The user spent months tuning another coding agent: instruction files, skills,
slash commands, memory, MCP servers. Your job is to carry that over so you
behave the way their old tool did — without carrying over anything dangerous,
and without pretending unsupported things came along.

## Non-negotiable rules — read before touching anything

- **Never copy credentials into your repo. Not once, not "temporarily."**
  Your repo is durable git history: a committed token stays leaked even after
  you delete the file. Credentials hide in MCP `headers` and `env` blocks,
  `.env*` files, and settings files. `~/.claude.json` contains the user's
  OAuth tokens — extract its `mcpServers` key with `jq`, never read or quote
  the file wholesale. When you find a credential: leave it out, name the KEY
  (never the value) in your summary, and offer to reconnect the service
  through you instead (`platform auth`).
- **Plan first, write after an explicit yes.** Present what you found, what
  you'll import and where, and what you're leaving out with reasons. Do not
  commit anything until the user confirms. They may trim the list — respect
  it exactly.
- **Import is additive.** Never overwrite your existing `soul.md` wholesale,
  never remove existing MCP servers or skills, and never write into
  `.memory/users/` (it has per-user privacy scoping you must not bypass).
- **Before pushing, sweep for secrets** even though you were careful:
  `git grep -inE '(api[_-]?key|secret|token|bearer |sk-[A-Za-z0-9])' -- ':!*.lock'`
  in your repo. Anything that looks like a real value gets removed before the
  push, and mentioned to the user.

## Where their setup lives

The files are on the **user's machine**, not in your sandbox. Read them
through the portal: `platform portal exec -- <cmd>` (for example
`platform portal exec -- ls -la ~/.claude`). If exec says you're not
authorized, run `platform portal request` and wait for the user's approval.

Don't rely on the table below as a fixed checklist — people rename projects,
nest repos, and mix tools. **Start with a discovery sweep, then use the table
to interpret what the sweep turns up.**

### Step 0: sweep the machine (do this first)

One `find` per home + likely project roots catches instruction files no matter
which tool wrote them or where the repo lives, including nested `AGENTS.md`.
Prune the big/noisy dirs so it stays fast:

```sh
platform portal exec -- sh -c '
  ROOTS="$HOME $HOME/src $HOME/code $HOME/dev $HOME/projects $HOME/repos $HOME/work $HOME/Documents/GitHub $(pwd)";
  for r in $ROOTS; do [ -d "$r" ] && echo "$r"; done | sort -u | while read -r root; do
    find "$root" -maxdepth 6 \
      \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .venv -o -name vendor -o -name target \) -prune -o \
      -type f \( \
        -iname AGENTS.md -o -iname AGENT.md -o -iname CLAUDE.md -o -iname CLAUDE.local.md \
        -o -iname GEMINI.md -o -iname CONVENTIONS.md -o -iname copilot-instructions.md \
        -o -iname .cursorrules -o -iname .windsurfrules \
        -o -name "*.mdc" -o -name "*.instructions.md" \
      \) -print 2>/dev/null;
  done | sort -u'
```

Also enumerate the per-tool config/skill/command dirs directly (these hold
skills, commands, MCP config, and memory the file-name sweep above won't catch):

```sh
platform portal exec -- sh -c '
  for d in ~/.claude ~/.claude/skills ~/.claude/commands ~/.agents ~/.codex ~/.gemini \
           ~/.config/opencode ~/.config/goose ~/.continue ~/.cursor ~/.aider.conf.yml \
           ~/.codeium/windsurf/memories ~/.config/zed "~/Documents/Cline/Rules"; do
    [ -e "$d" ] && { echo "== $d =="; ls -la "$d" 2>/dev/null; }
  done'
```

Then read the interesting hits **individually** — don't cat whole directories
blind, and never cat a credential file wholesale (see the rules above).

### Reference: what each tool leaves on disk

Use this to recognize and interpret what the sweep found. Global paths are
`~/`-rooted; the rest are project-relative and can appear at any nesting level.

| Tool                    | Instructions / rules / memory                                                                                                                                                           | Skills · commands                                                                   | MCP config                                                                                               | ⚠️ credential file (never read wholesale)                      |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Claude Code**         | `~/.claude/CLAUDE.md` · project `CLAUDE.md`, `CLAUDE.local.md`, `.claude/CLAUDE.md`, `.claude/rules/*.md` · project memory `~/.claude/projects/<path-with-non-alnum-as-dashes>/memory/` | `~/.claude/skills/`, `.claude/skills/` · `~/.claude/commands/`, `.claude/commands/` | project `.mcp.json` + `mcpServers` key of `~/.claude.json`                                               | `~/.claude.json` (OAuth tokens — `jq` out `.mcpServers` only)  |
| **Cursor**              | `.cursor/rules/*.mdc` (frontmatter `description`, `globs`) · legacy `.cursorrules`                                                                                                      | `.cursor/skills/`, `.cursor/commands/`                                              | `.cursor/mcp.json`, `~/.cursor/mcp.json`                                                                 | —                                                              |
| **OpenCode**            | project `AGENTS.md` · `~/.config/opencode/AGENTS.md`                                                                                                                                    | `.opencode/skills/`, `.opencode/commands/`                                          | `mcp` key of `opencode.json`/`.jsonc` (JSONC — allows comments), also `~/.config/opencode/opencode.json` | —                                                              |
| **OpenAI Codex CLI**    | project `AGENTS.md` · `~/.codex/AGENTS.md`                                                                                                                                              | prompts under `~/.codex/prompts/`                                                   | `[mcp_servers]` table in `~/.codex/config.toml` (TOML) · project `.codex/config.toml` (only if trusted)  | env vars only — but scan `config.toml` for inline tokens       |
| **Gemini CLI**          | `~/.gemini/GEMINI.md` · nested project `GEMINI.md` (hierarchical)                                                                                                                       | —                                                                                   | `mcpServers` key of `~/.gemini/settings.json` + project `.gemini/settings.json` (JSON)                   | env vars; scan `settings.json` `headers`/`env`                 |
| **GitHub Copilot**      | `.github/copilot-instructions.md` · `.github/instructions/*.instructions.md` (frontmatter `applyTo`) · `AGENTS.md`                                                                      | —                                                                                   | —                                                                                                        | —                                                              |
| **Windsurf**            | `.windsurf/rules/*.md` (frontmatter `trigger`, `globs`) · legacy `.windsurfrules` · `AGENTS.md` · global `~/.codeium/windsurf/memories/global_rules.md`                                 | —                                                                                   | —                                                                                                        | —                                                              |
| **Cline**               | `.clinerules/*.md` (frontmatter `paths`) · `AGENTS.md` · `~/.agents/AGENTS.md` (global) · `~/Documents/Cline/Rules/`                                                                    | —                                                                                   | —                                                                                                        | `~/.cline/` (file-backed secret stores)                        |
| **Roo Code**            | `.roomodes` (mode defs) · `.rooignore`                                                                                                                                                  | —                                                                                   | —                                                                                                        | —                                                              |
| **Aider**               | `CONVENTIONS.md` · `.aider.conf.yml` `read:` list                                                                                                                                       | —                                                                                   | —                                                                                                        | `~/.aider.conf.yml` / `.aider.conf.yml` (`*-api-key:`), `.env` |
| **Continue.dev**        | —                                                                                                                                                                                       | `~/.continue/config.yaml` `rules`/`prompts`                                         | `mcpServers` in `~/.continue/config.yaml` (also `.json`/`.ts`)                                           | `~/.continue/config.yaml` (provider `apiKey`)                  |
| **Goose**               | —                                                                                                                                                                                       | `~/.config/goose/prompts/`                                                          | `extensions` key of `~/.config/goose/config.yaml` (YAML)                                                 | `~/.config/goose/secrets.yaml`                                 |
| **Zed**                 | instructions in `~/.config/zed/settings.json` / project `.zed/settings.json`                                                                                                            | —                                                                                   | MCP (`context_servers`) in `settings.json`                                                               | scan `settings.json` for keys/tokens                           |
| **Cross-tool standard** | `AGENTS.md` (plural, the standard) and `AGENT.md` (singular variant) at repo root **and any subdirectory** — nearest wins · global `~/.agents/AGENTS.md`                                | `.agents/skills/`                                                                   | —                                                                                                        | —                                                              |

Directories are often symlinked into each other (`.claude/skills` →
`.agents/skills`; other tools auto-read each other's `AGENTS.md`/`.cursorrules`)
— **dedupe by content and import each thing once.** The same rules file surfaced
by three tools is one import, not three.

For config formats other than JSON: `opencode.json` is JSONC (strip comments
before parsing), Codex is **TOML**, Aider/Goose/Continue are **YAML**. Pull the
MCP block out with the right parser, not a naive `JSON.parse`.

## Where it goes in your repo

- **Personal working preferences** (how they like diffs, reviews, tone) →
  distill the essence into `soul.md`, under your normal soul-editing rules.
  Keep it short; a 400-line CLAUDE.md pasted into your soul makes you worse,
  not better. If they want the full text preserved verbatim, put it in
  `AGENTS.md` at your repo root (the harness loads that file every session)
  with a comment noting where it came from.
- **Project-specific conventions** ("this repo uses X"): prefer leaving them
  in that project and reading its `AGENTS.md`/`CLAUDE.md` when you actually
  work there. Import into your own `AGENTS.md` only guidance the user wants
  applied everywhere. Ask when it's ambiguous.
- **Skills** → `skills/<name>/SKILL.md`, copied as-is (same format, including
  `scripts/`/`references/` subdirectories). Skills are re-scanned every chat
  request, so they work as soon as you commit.
- **Slash commands** → they have no equivalent here, so convert each into a
  skill: `skills/<kebab-name>/SKILL.md` with frontmatter `name`,
  `description` (from the command's frontmatter or first line), and
  `disable-model-invocation: true` so it only runs when the user asks for it
  by name. `$ARGUMENTS` placeholders and !`cmd` shell-injection don't execute
  in skills — rewrite the body so it reads as instructions to you.
- **Memory files** (Claude Code) → `.memory/`, filed by their
  `metadata.type`: `feedback` → `.memory/feedback/`, `project` →
  `.memory/projects/`, `reference` → `.memory/reference/`, anything else →
  `.memory/imported/`. Every file needs frontmatter `name` and `description`
  — the memory index is path + description, so a file without one is
  invisible to you. Skip their `MEMORY.md` index; yours is built from
  descriptions.
- **MCP servers** → merge into the `servers` map of `mcp.config.json`
  (`{"transport": "stdio", "command", "args", "env"}` or
  `{"transport": "http", "url", "headers"}`). Constraints that WILL bite:
  - Strip every credential-looking header/env value (see rules above). For
    OAuth servers the user reconnects via
    `platform auth mcp <url> --service "<Product>"`; header tokens go through
    `platform auth configure` proxy rules — never into this file.
  - `sse` transport isn't supported — skip, tell the user.
  - stdio servers run in YOUR sandbox now: one that references a path on the
    user's machine (`/Users/...`, `~/...`) can't work — skip it and say so.
    One that runs a package (`npx …`) usually works but may need
    dependencies added to your `install.sh`/`Dockerfile`.

## What cannot come along — say so, don't silently drop

Hooks and settings/permissions (Claude Code `settings.json`, Cursor
`hooks.json`), file-based subagent definitions, editor plugins, output
styles, keybindings, and session history have no equivalent here. List
whichever you found in your plan under "not importable" with one honest line
each. The user deciding "fine" is part of the migration.

## Procedure

1. **Inventory**: run the Step 0 sweep first, then the per-tool dir listing,
   then read the interesting hits via portal. Note what exists, which tool it
   came from, sizes, and obvious duplicates (same content via multiple tools).
2. **Present the plan**: found → import to where → leaving out and why
   (credentials, unsupported, machine-specific). Wait for the yes.
3. **Apply**: write the files, commit with a message like
   `import: Claude Code + Cursor setup`, and push — the push is what makes
   it live for your next turn.
4. **Verify**: run the secret sweep before the push; after it, confirm the
   skills index picks up the new skills on your next reply and quote one
   imported preference back so the user sees it took.
5. **Offer the follow-ups**: distilling their preferences into your soul if
   you haven't, reconnecting each stripped MCP server, and importing other
   projects' configs when they next work there with you.

## Re-import

If the user runs an import again, update the files you previously imported
in place (your provenance comments mark them) instead of appending
duplicates. Content they edited by hand since then: ask before replacing.
