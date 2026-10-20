---
name: scheduled-workflows
description: Author a workflow automation — a scheduled routine whose check runs as a script in your sandbox with NO agent turn, waking you only when there is something to act on (exit 42) or the script fails. Read before creating or converting any watch/poll routine (PR/CI watchers, inbox sweeps, queue reapers, release radars), and when a firing hands you escalated workflow output.
---

# Scheduled workflows

A plain automation wakes you on **every** firing — a full agent turn even when
the check finds nothing, which for watch/poll routines is most firings. A
**workflow automation** inverts that: the platform runs your script at each
firing, and _the script_ decides whether you get involved. You pay an agent
turn only on the firings that matter.

If workflow automations aren't enabled for your organization (`platform automation create` returns a clear error saying so), create a plain automation instead — everything else here about writing a good description still applies.

Use a workflow when the routine's check is deterministic — a fixed command
whose output says whether there is anything to do. Keep a plain automation
when every firing genuinely needs your judgment (a digest you compose, a task
that always acts).

## The script contract

Your command is executed in your own sandbox (same environment as your turns:
`platform` CLI, credentials, your files). Its exit code is the whole protocol:

| Exit                      | Meaning        | What happens                                                                                                                                                                                            |
| ------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0`                       | Nothing to do  | Firing completes quietly. Whatever you printed is stored as the run's record in the routine history — print a one-line status (`no new release (latest still v26.8.1)`), not silence.                   |
| `42`                      | Wake the agent | A full agent turn starts, and your stdout is delivered to it as context. Print exactly what the woken agent needs: the finding, the IDs, the delta.                                                     |
| anything else, or timeout | Failure        | Per `--on-failure`: `escalate` (default) wakes you with the failure detail — do the routine's work manually that turn, **then fix the script**; `fail` records a failed firing (bounded retries apply). |

When a firing wakes you with `[workflow]` output: the check has already run.
Act on the output — do not re-run the check unless you need fresher data.

## Authoring

```
platform automation create "<full instruction for your woken self>" \
  --cron "*/10 * * * *" --tz <tz> \
  --title "..." --summary "..." \
  --workflow-command 'bash ~/.workflows/<name>.sh' \
  [--workflow-timeout <seconds>] [--on-failure escalate|fail]
```

- **Dry-run before you create.** Run the script once (and force the escalate
  branch once, if you can) _before_ calling `platform automation create`. A
  check that fails at authoring time will fail on every firing. If the dry run
  errors or surprises you — a 404, an auth failure, a placeholder that looks
  unexpanded (`$VAR` in a URL the user gave you) — **fix it or ask the user
  now**; never schedule a check you haven't seen succeed.
- **Keep the script in a file** (`~/.workflows/<name>.sh`), not inline — you
  will edit it over time, and a failure escalation tells you to fix it.
- **The description still matters.** It is the instruction the woken turn
  follows on escalation, so it must stand alone: targets, accounts, IDs, what
  "done" looks like — same rules as any automation.
- Timeout: 5–600 s, default 120. The script is killed at the budget and the
  firing follows `--on-failure`.
- Convert an existing routine either way: `platform automation update <id>
--workflow-command '...'` or `--clear-workflow`.

## Writing a check that can be trusted

A workflow's only failure mode that matters is a **false quiet** — exiting 0
when there was work, or when the check itself broke. The world your script
depends on changes after you wrote it: an API path gets retired (404), a
token expires (401), a response changes shape. A script that turns any of
those into an empty result, and the empty result into "nothing new", is
quiet forever and nothing wakes you. Guard against it:

- **Start every script with `set -euo pipefail`.** With `-e`, a failing
  `curl`, `gh`, or `jq` exits the script non-zero and the default escalation
  wakes you on the _first_ firing. Without it the failed fetch becomes an
  empty variable, and the empty variable becomes "nothing to do". `-e` has
  blind spots: it is off inside `if`/`while` conditions and on the left of
  `&&`/`||`, and it ignores a command substitution nested in another
  command's arguments (`echo "$(curl …)"`). So check a fetch's exit status
  yourself, exactly as the example does (`if ! body=$(curl …); then … exit 1`)
  — never `|| true` a fetch, and never test the body for emptiness in place
  of the exit code.
- **Anything the check depends on erroring is a script error.** Use
  `curl --fail-with-body` or `gh api` (both exit non-zero on 4xx/5xx), and
  treat a response you cannot parse or that lacks the field you expect as an
  error, not as "no items".
- **Quiet must be positively observed.** The quiet line prints the evidence
  you actually saw — the status, the count, the newest id
  (`HTTP 200, 1234 followers, newest 9f3c`) — never a conclusion drawn from
  absence. An empty list from an endpoint you did not confirm returned 200
  is not quiet.
- **Observe the trigger condition itself, never a proxy.** Ask: "could my
  woken self ever act on something this command doesn't print?" If yes, the
  check is incomplete. (`gh pr view --json state,mergeStateStatus` for a PR
  watcher: yes. `updatedAt` as a stand-in for "anything reviewable happened":
  no.)
- **Time-based conditions: compute the boolean inside the script.** "Stale for
  over 2h" can become true while the world is byte-identical — print
  `stale=true`, decided against the current time, not raw timestamps.
- **"New items" checks: key on a dedup set or watermark you maintain**, not on
  timestamps alone — late arrivals are real. Keep that state in a file next to
  the script or in `platform db`, never assume you remember it.
- **Advance the watermark only after the action succeeds — never in the
  script before `exit 42`.** A script that stamps the state and then wakes you
  has already marked the item "handled" before anything happened: if your
  escalated turn fails (the post errors, you get cancelled), every later
  firing sees the advanced watermark and stays quiet — the alert is lost
  forever. Print the candidate watermark in the escalation output and write it
  yourself, in the woken turn, after the action lands. Re-waking twice on the
  same item is a nuisance; never waking on it is the failure mode this whole
  design exists to prevent.
- **Fail loud, not quiet.** If the check itself errors (API down, auth
  expired, a secret or env var it needs is missing), exit non-zero — the
  default escalation wakes you to handle it. Never swallow an error into
  `exit 0`: a silent stand-down looks exactly like "nothing to do", forever.

## Worked example

`~/.workflows/node-release-watch.sh` — escalate when a new Node.js release
appears:

```bash
#!/usr/bin/env bash
set -euo pipefail              # any failing command exits non-zero -> escalate, never a false quiet
STATE=~/.workflows/state/node-release.last
mkdir -p "$(dirname "$STATE")"

# --fail-with-body: a non-2xx (a retired endpoint's 404, an auth 401) is an
# error carrying its body, never an empty "nothing new".
if ! body=$(curl -sS --fail-with-body https://api.github.com/repos/nodejs/node/releases/latest); then
  echo "release lookup failed: $body" >&2
  exit 1                       # failure -> escalate (default): you get woken to investigate
fi
tag=$(jq -r .tag_name <<<"$body")
if [ -z "$tag" ] || [ "$tag" = "null" ]; then
  echo "unexpected response: $body" >&2
  exit 1
fi

last=$(cat "$STATE" 2>/dev/null || true)
if [ "$tag" != "$last" ]; then
  # Do NOT write $STATE here — the woken turn advances it after the post
  # succeeds, so a failed escalation re-fires instead of going silent.
  echo "NEW RELEASE: $tag (previous: ${last:-none})"
  echo "after acting: echo $tag > $STATE"
  exit 42                      # wake the agent with this output
fi

echo "no new release (HTTP 200, latest still $tag)"
exit 0                         # quiet, with the evidence: stored in run history, no turn
```

Created with:

```
platform automation create \
  "Node.js release radar. When woken with a NEW RELEASE line, post one short message to #eng-updates naming the version and linking its release notes. After the post succeeds, run the 'after acting' command from the output to advance the watermark." \
  --cron "0 * * * *" --title "Node release radar" \
  --summary "Checks hourly for a new Node.js release and posts it to #eng-updates." \
  --workflow-command 'bash ~/.workflows/node-release-watch.sh'
```
