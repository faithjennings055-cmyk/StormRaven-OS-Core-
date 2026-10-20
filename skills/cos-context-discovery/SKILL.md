---
name: cos-context-discovery
description: Build the working model of the principal's world — relationships, patterns, voice, priorities, and constraints — by mining available history before making calls on their behalf. Use at instantiation, after a role or org change, or when handling errors reveal a gap in the model.
---

# Context discovery

## Objective

Learn the principal from evidence rather than from a questionnaire. Most of what you need
is already visible in how their last ninety days actually ran. Ask only for what history
cannot show.

## Why this runs before triage

Triage is a series of judgment calls made in someone else's name. Every one of them —
whether this sender gets same-day access, whether this meeting can move, how warm a
decline should read — depends on a model of the principal you do not have on the first
turn. Running triage without it produces confident, plausible, wrong decisions. Spend the
time here; it is recovered many times over.

## Parallel dispatch

Verify access before dispatching. Calendar read powers Rhythm; Gmail read powers Voice and
most of Relationships and Substance, so a missing mail connection removes roughly three of
the four surfaces rather than degrading all of them evenly. Establish what is actually
connected first, dispatch only the surfaces you can serve, and state the resulting coverage
before presenting any conclusion drawn from it.

These surfaces are independent and should be read concurrently by separate subagents, one
per surface, each read-only and each returning structured findings rather than raw
content. Dispatch them together and synthesize once they land. Where a platform provides
no subagent primitive, run the same passes sequentially and say so in the completeness
report — do not silently narrow coverage instead.

| Subagent | Surface | Returns |
| :--- | :--- | :--- |
| **Rhythm** | Calendar history, 60–90 days | Real working hours, time zone and travel, meeting load and trend, recurring structure, protected blocks, buffer habits, no-show and reschedule patterns |
| **Relationships** | Calendar attendees plus correspondence metadata | Who they meet and how often, who gets same-day access, who they never decline, who has gone quiet, internal versus external mix |
| **Voice** | Sent correspondence only | Register per relationship tier, salutation and sign-off conventions, sentence length, what they never say, how they decline, how they chase |
| **Substance** | Documents, recurring agendas, threads they engage with | Organization and product truth, role and reporting lines, priorities as demonstrated, live projects, vocabulary and internal shorthand |

Each subagent reports findings with confidence labels and the count of items it read. A
subagent that cannot access its surface reports that plainly; it never estimates from the
other surfaces.

## Synthesis

1. Reconcile the four reports. Where two surfaces disagree — the stated working hours
   against the hours actually booked, the claimed priority against the calendar — record
   the conflict rather than averaging it. These conflicts are frequently the most useful
   thing discovery produces, and several are worth raising with the principal directly.
2. Distinguish a pattern from a coincidence. Three instances is a pattern; one is an
   anecdote. Label accordingly and never encode an anecdote as a rule.
3. Separate the stable from the seasonal. A quarter-end crush, a hiring push, or a
   launch distorts the picture; note the window you measured and whether it looks typical.
4. Write confirmed facts into the `## Organization context` section of the soul. Preserve
   unknowns as unknowns and keep the confidence label attached to anything inferred.

## The ask list

After synthesis, you will still be missing things history cannot show: what they want to
stop doing, which relationships are strategic versus obligatory, the real reason a
standing meeting exists, spending authority, and where the send-versus-draft line sits.

Rank these by how much damage a wrong guess causes, keep the list to the few that matter,
attach your best inference as a proposed default to each, and ask them as confirmations
rather than open questions. "I'll treat the Monday staff meeting as immovable and the
Thursday sync as fair game — correct?" beats "What are your scheduling preferences?"

## Privacy constraints

This pass reads more of the principal's private material than any other, and much of it
was written by people who did not consent to your reading it. Therefore:

- Read-only, always. Discovery never sends, replies, files, or modifies.
- Record patterns and conclusions, never verbatim content. Organization context is a
  model of how this person works, not an archive of what was said to them.
- Personal, medical, legal, financial, and personnel-sensitive material informs handling
  silently. It is never written into context, summarized to a third party, or referenced
  in a channel others can read.
- Never expose one counterparty's information to another as a side effect of scheduling
  or drafting.
- If the principal asks what you learned, tell them completely and plainly. The
  discretion is directed outward, never at them.

## Completeness

Report the surfaces read, the window covered, item counts per surface, which subagents
came back empty, the conflicts found, and the ask list. Never present a model built from
one surface as though it came from four.
