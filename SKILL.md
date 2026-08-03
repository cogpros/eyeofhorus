---
name: eyeofhorus
description: "Incident-attribution and bug-hunting engine, two modes. BOX MODE (no index needed): something happened on the machine — a pull, a write, a job firing, a state change — and name-search came back clean; the temporal overlay attributes it by CLOCK, correlating every log surface on one UTC timeline (references/overlay.sh). REPO MODE (needs a GitNexus index, <7 days fresh): full-system bug sweeps using graph topology + the autoresearch:debug scientific method. Named for the eye that was shattered and rebuilt. Hands off to /autoresearch:fix for repair, /prism or /verify-your-work for high-stakes findings. NOT FOR: a single known bug with a stack trace (use /autoresearch:debug), one-file edits, or content/copy/design work."
user-invocable: true
metadata:
  version: "2.0.0"
  author: "dustinpollock"
  cogpros-primitive: "Sentry"
triggers:
  - "eyeofhorus"
  - "use eyeofhorus"
  - "who did this"
  - "what pulled that"
  - "attribute this"
  - "find all bugs"
---

# EyeofHorus

The eye that was shattered and rebuilt. Sees the whole system at once — as a
code graph when the quarry is code, as one clock-ordered timeline when the
quarry is an *event* — then proves what happened through scientific method.

**v2, 2026-08-02.** Rebuilt on the evidence of its own first 21 runs. What the
record kept: gather, the temporal overlay, atomic hypothesis testing, and the
finding format. What it dropped: a composite score that had never once
executed, a TSV whose "graph impact" column held entries like `daily`, and
the ceremony the winning runs consistently skipped. The best run in its
history (the 2026-08-02 mystery-pull attribution) used one phase this file
used to describe in prose only. That phase now has hands.

## When to Use

- **Whodunits (box mode).** Something happened and grep came back clean — the
  actor may be a transient process, since-replaced code, or a hidden
  dependency no current file expresses. Name-search reads what the system
  *says*; the overlay reads what it *did*. Proven: five exhaustive name-based
  hunts (including a cross-model blind leg with command access) missed an
  unattributed model pull; one time-bucketed pass attributed it in minutes to
  a 60-second process running code that no longer existed on disk.
- **Evidence smeared across 3+ systems** (logs + cron + agents + git) for one
  question.
- **Full-system bug sweeps (repo mode)** across GitNexus-indexed codebases;
  post-deploy verification; pre-release confidence checks.
- Any time /autoresearch:debug would benefit from topology it can't see.

## When NOT to Use

- Single known bug with a stack trace → `/autoresearch:debug` (tier 2), or
  `/systematic-debugging` (tier 1) if the error is in hand. Most bugs die at
  tier 1. Do not jump tiers.
- One-file edits, config tweaks, content/copy/design.

## Mode selection (first decision, before anything else)

| Quarry | Mode | GitNexus |
|---|---|---|
| An EVENT: who/what did X, when, why did state change | **box** | not used |
| A DEFECT in code: what is broken across this repo | **repo** | **required** — index <7 days fresh; reindex with `npx gitnexus analyze` from the repo root |
| Both (an event caused by a code defect) | box first, then repo on what it implicates | as needed |

GitNexus is a repo-mode instrument, not an entry fee. The skill's best-proven
work needed no index.

## Setup

```bash
SLUG="short-case-name"
OUTDIR="$HOME/.eyeofhorus/$(date +%y%m%d-%H%M)-${SLUG}"
mkdir -p "$OUTDIR"
```

**The home is absolute and canonical.** Every run ever lives under
`~/.eyeofhorus/`. (v1's cwd-relative path scattered 19 runs across eight
directories — five inside this skill's own package, which then got published.)

## Phase 0 — READ THE LEDGER (mandatory, ~1 min)

The eye remembers its hunts. Before forming a single hypothesis:

```bash
head -40 ~/.eyeofhorus/LEDGER.md                # every prior run, one line each
grep -rli "<quarry keywords>" ~/.eyeofhorus/*/findings.md \
     ~/.eyeofhorus/*/eliminated.md 2>/dev/null
```

If a prior run already eliminated a hypothesis you were about to test, you
just saved an hour. (The day this skill's best case ran, FIVE independent
hunts re-searched ground the first had already cleared, because nothing
recorded "name-search exhausted." The ledger is the fix.)

## Phase 1 — Gather

Collect the error signals before touching code: relevant logs, failing tests,
recent git history (`git log --since` on implicated repos), bus events, the
user's own account of symptoms. In box mode this phase IS the hunt's raw
material; be generous.

## Phase 1.5 — Temporal Overlay (box mode's main weapon)

**Run the instrument; do not improvise the sweep:**

```bash
bash <skill-dir>/references/overlay.sh \
     --around <UTC-timestamp> --window 120 [--grep pattern]
```

One command emits a UTC-normalized, clock-ordered timeline across the box's
log surfaces: your machine's log surfaces (whatever you wired into references/overlay.sh —
event buses, service logs, server access logs, job-run histories).

**Why the script and not your own greps:** this box logs in two clocks six
hours apart, and one surface (the ollama server log) carries no timezone
marker at all. A naive join silently returns an empty correlation table that
reads as "no hidden dependency" when it means "you compared 17:20 to 23:20."
The script encodes the conversion. (SK is UTC-6 with no DST; if the box ever
moves, fix `LOCAL_UTC_OFFSET` in the script.)

**How to read the output:** events from DIFFERENT sources inside the same 2-3
second bucket, with no code path connecting them, are the prize — a hidden
dependency the system's files don't express. "None is the interesting case."

## Phase 2 — Map (repo mode only)

Use the live MCP tools (`mcp__gitnexus__*`):
- `query` — find symbols/flows matching the error signals
- `context` — 360° view of a symbol: callers, callees, flows
- `impact` — blast radius of a suspect node, upstream/downstream
- `cypher` — arbitrary graph queries when the canned ones can't ask it
- `detect_changes` / `list_repos` — recent-change correlation, index roster

Build a short prioritized target list in `$OUTDIR/attack-surface.md`:
runtime-error nodes with high fan-out first, then temporal-correlation pairs
with no graph edge, then error-adjacent recent changes. Known blind spot: the
index has no bash grammar — shell orchestration (most of this stack) is
invisible to the graph; hunt it in box mode instead.

## Phase 3 — Hypothesize

```
Hypothesis N: "<specific, falsifiable claim>"
Basis: <the graph node / overlay bucket / log pattern that suggested it>
Test: <the ONE experiment that would prove or disprove it>
```

Prior eliminated hypotheses (Phase 0) are off the menu unless new evidence
reopens them — say so explicitly if you reopen one.

## Phase 4 — Test

One atomic experiment per iteration: direct inspection, execution trace,
minimal repro, binary search, git differential, graph-flow walk (repo mode),
or overlay re-run on a narrower window (box mode). The experiment's output —
not your confidence — decides.

## Phase 5 — Findings

Confirmed findings go in `$OUTDIR/findings.md`:

```
### [SEVERITY] <title>
- Location/actor: <file:line, or process/job/agent for box mode>
- Evidence: <the experiment + its output>
- Root cause: <WHY, not just what>
- Disconfirming test: <what would have to be true for this to be WRONG,
  and the check that showed it isn't>
- Suggested fix: <concrete change>
```

**No `Disconfirming test`, no CONFIRMED.** Same-mind confirmation is this
box's proven failure mode — the field forces the adversarial move inside the
turn. For high-stakes findings, escalate to `/prism` or `/verify-your-work`
(cross-model verification) before anything irreversible acts on them.

Disproven hypotheses go in `$OUTDIR/eliminated.md` — one line each, with the
evidence that killed them. **This file is the ledger's food; skipping it is
how the next hunt re-plows your ground.**

## Phase 6 — Feed the Ledger (mandatory, ~1 min)

```bash
echo "| $(date -u +%Y-%m-%dT%H:%MZ) | ${SLUG} | <mode> | <N confirmed / M eliminated> | <one-line outcome> |" \
  >> ~/.eyeofhorus/LEDGER.md
```

Then, judgment calls, not ritual: card residue on the kanban if work remains;
emit a bus event if the finding changes system state; hand to
`/autoresearch:fix` if repair is wanted (`--fix`).

## Iteration and stopping

Loop 3→4→5 while hypotheses remain. Bounded runs (`--iterations N`) stop and
summarize. Unbounded runs require an interactive operator — never run
unbounded from cron. Diminishing returns (3 iterations, nothing new) = say so
and stop; a clean "nothing found, here is what was ruled out" is a valid and
valuable outcome — write it to eliminated.md so it stays found.

## Chaining

- `/eyeofhorus --fix` → hand confirmed findings to `/autoresearch:fix`
- `/prism $OUTDIR/findings.md` → adversarial review of a high-stakes finding
- Tier ladder: `/systematic-debugging` (tier 1) → `/autoresearch:debug`
  (tier 2) → here (tier 3)

## Known Limitations

1. **GitNexus indexes go stale and have no bash grammar** — repo mode is
   blind to shell orchestration; use box mode for it.
2. **The overlay's source list is this box's.** New log surfaces (new agents,
   new daemons) must be added to `references/overlay.sh` or they are invisible
   to the timeline. When a hunt dead-ends, ask first: is the actor logging
   somewhere the overlay doesn't sweep?
3. **The overlay attributes; it does not prove.** A lane-holder in the right
   window is a suspect, not a conviction — Phase 4 still has to close the
   causal chain (the mystery-pull case needed the bundled old code + the
   auto-pull behavior to convict).
4. **macOS unified log is not swept** (too slow inline). For process-level
   attribution the overlay can't reach:
   `log show --start '<local>' --end '<local>' --predicate '...'`
   — note it takes LOCAL time, not UTC.

## Lineage

autoresearch:debug (scientific method) × GitNexus (graph omniscience) +
the temporal overlay (its own invention, and the reason it earns a name).
v1 2026-03-27; v2 2026-08-02, rebuilt from its own run record: 21 runs, three
full-artifact compliers, one case — the mystery pull — that five other
hunters missed and Phase 1.5 closed in minutes. The scoring machinery v1
carried was removed after the record showed it had never executed; if a
future metric is wanted, calibrate it against Ghost Hours FW-C from real
runs, not invented weights.
