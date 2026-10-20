# Memory index

This file is your hand-written index of durable memory. The harness injects it
into your system prompt every turn, so keep it a lean, high-signal table of
contents — not a store. Bodies are NOT auto-loaded; when an index line looks
relevant, open that file with your read tool.

When you learn something durable, write the fact to its own `.md` file under
`.memory/` and add ONE pointer line here in the form:

    - [Title](relative/path.md) — one-line hook describing when to open it

Start each topic file with `name:` / `description:` frontmatter so this index
can be regenerated from the files themselves. Lay files out as
`projects/<slug>/<topic>.md`, `feedback/<topic>.md`, or `reference/<topic>.md`.

Behavior rules (how you should act) belong in `soul.md`, not here — memory
records what happened, soul defines how you behave.

**Persist your changes.** After editing `soul.md` or anything under `.memory/`,
commit and push so it survives a sandbox restart:

    git add -A && git commit -m "update memory" && git push

(No entries yet — add pointer lines above as you learn things worth carrying
across conversations.)
