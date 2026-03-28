# EyeofHorus

Graph-powered autonomous bug hunter. Sees the whole system at once through GitNexus,
then proves what's broken through scientific method. Named for the eye that was shattered
and rebuilt. Sees deeper than the original.

## When to Use

- Full-system bug sweeps across indexed codebases
- Post-deploy verification ("did we break anything?")
- Infrastructure health audits (crons, pipelines, integrations)
- Pre-release confidence checks
- Any time autoresearch:debug would benefit from knowing the codebase topology

## When NOT to Use

- Single known bug with a stack trace (just use autoresearch:debug)
- Codebase not indexed by GitNexus (run `npx gitnexus analyze` first)
- Quick config fixes or one-file edits
- Non-code problems (content, copy, design)

## Invocation

```
/eyeofhorus
```

Or with flags:

```
/eyeofhorus --scope ./my-project/ --severity high --fix
/eyeofhorus --scope src/ --iterations 20
```

Triggers: "scan everything", "find all bugs", "system health check", "eyeofhorus"

## Prerequisites

1. GitNexus index must exist and be reasonably fresh for the target repo
2. Check freshness: read `gitnexus://repo/{name}/context`
3. If stale (>7 days or significant changes since index): run `npx gitnexus analyze` first

## Architecture

```
/eyeofhorus
  Phase 1:   Gather (symptoms, logs, error signals)
  Phase 1.5: Overlay (map log events to graph nodes, temporal correlation)
  Phase 2:   Map (GitNexus graph reconnaissance)
  Phase 3:   Hypothesize (graph-informed, prioritized)
  Phase 4:   Test (prove or disprove, one experiment at a time)
  Phase 5:   Classify (severity + graph impact)
  Phase 6:   Log + Score (composite metric)
  Phase 7:   Hunt (next target from graph, pattern search)
```

## Setup

Before executing any phase, create the output directory:

```bash
SLUG="${TOPIC:-eyeofhorus-scan}"
OUTDIR="eyeofhorus/$(date +%y%m%d-%H%M)-${SLUG}"
mkdir -p "$OUTDIR"
```

All output files go in `$OUTDIR`.

## Phase 1: Gather

Collect all available error signals before looking at code.

**Signal sources (check all that apply):**
- Log files: scan for errors, warnings, stack traces
- Test suite: run tests, collect failures
- Linter/typecheck: run if available, collect issues
- Gateway/service logs: tail recent entries for error patterns
- Git history: recent changes that correlate with error onset
- User-reported symptoms

**Output:** `[EYEOFHORUS] Phase 1: Gathered. {N} error signals from {M} sources.`

## Phase 1.5: Runtime Overlay

This phase bridges the gap between static code knowledge (GitNexus) and live system behavior (logs).
GitNexus maps what the code says. The overlay maps what the code does.

**Step 1: Parse recent logs into structured events**

Scan all available log sources. For each error/warning, extract:
```
{timestamp, component, severity, message, file_hint}
```

`file_hint` = any filename, function name, or module name mentioned in the log line.
This is the anchor for mapping the event to a graph node in Phase 2.

**Step 2: Compute runtime stats per component**

For each unique component in the parsed events:
- Error frequency (count per hour/day)
- Restart count (if applicable)
- Last occurrence timestamp
- Error trend (increasing, stable, decreasing)

**Step 3: Temporal correlation**

Group events by time window (2-second buckets). Events that co-occur repeatedly
are candidates for shared root cause, even if the graph shows no direct connection.

```
Correlated pair: {component_A} and {component_B}
  Co-occurrence: {N} times in {M} hours
  Average gap: {ms}
  Graph connection: {direct / indirect / none}
```

"None" is the interesting case. Two components failing together with no graph edge
between them means there's a hidden dependency the code doesn't express.
That's a high-priority investigation target.

**Step 4: Annotate the attack surface**

Pass the runtime stats and correlations forward to Phase 2.
Nodes with runtime errors get priority over nodes that are only structurally suspicious.

**Output:** `[EYEOFHORUS] Phase 1.5: Overlay. {N} components with runtime errors. {M} temporal correlations found.`

## Phase 2: Map (GitNexus Reconnaissance)

This is what makes EyeofHorus different from autoresearch:debug. Instead of manually
grepping through files, query the knowledge graph.

**Step 1: Load the graph context**

Read `gitnexus://repo/{name}/context` to get:
- Total symbols, relationships, execution flows
- Index freshness
- Community structure (clusters of related code)

**Step 2: Load execution flows**

Read `gitnexus://repo/{name}/processes` to get the full list of execution flows.
For flows that intersect with Phase 1/1.5 error signals, read the detail:
`gitnexus://repo/{name}/process/{processName}`

**Step 3: Map error signals to graph nodes**

For each error signal from Phase 1 and runtime annotation from Phase 1.5:
- Use `query` tool with error-related keywords to find matching symbols
- Use `impact` tool on affected files to map upstream/downstream dependencies
- Use `context` tool on specific symbols for 360-degree view (callers, callees, processes)

**Step 4: Build the attack surface**

From the graph queries, build a prioritized list of investigation targets:

```
Priority 1: Nodes with runtime errors AND high fan-out (many dependents)
Priority 2: Nodes in temporal correlation pairs with no graph edge (hidden deps)
Priority 3: Nodes with errors AND low test coverage
Priority 4: Nodes on critical execution flows (auth, data, payments)
Priority 5: Nodes with recent git changes in error-adjacent code
Priority 6: Remaining error signals
```

Write the attack surface to `$OUTDIR/attack-surface.md`.

**Step 5: Coverage tracking**

Record total execution flows in the graph vs flows that intersect with error signals.
This feeds the coverage component of the composite metric.

```
coverage_pct = (flows_investigated / total_flows) * 100
```

**Output:** `[EYEOFHORUS] Phase 2: Mapped. {N} nodes on attack surface. {M}% flow coverage. {P} priority targets.`

## Phase 3: Hypothesize (Graph-Informed)

Form hypotheses using graph topology, not just code reading.

**Graph-informed hypothesis strategies:**

| Priority | Strategy | GitNexus Tool/Resource |
|----------|----------|------------------------|
| 1 | Error node with most dependents | `impact` tool, sort by depth-1 count |
| 2 | Broken execution flow | `gitnexus://repo/{name}/process/{name}` step trace |
| 3 | Temporal correlation with no graph edge | Phase 1.5 output + `cypher` to verify no path |
| 4 | Cross-boundary data corruption | `gitnexus://repo/{name}/clusters` + `context` on boundary nodes |
| 5 | Missing dependency | `context` tool, check for expected callers/callees that don't exist |
| 6 | Cascading failure | `impact` tool on confirmed bug, follow dependent chain |

**Hypothesis format:**
```
Hypothesis {N}: "{specific, testable claim}"
Graph basis: {which node/edge/flow informed this}
Runtime basis: {which log pattern or correlation, if any}
Testing via: {experiment type}
```

## Phase 4: Test

One experiment per iteration. Atomic.

**Experiment types:**
- Direct inspection (read the code)
- Trace execution (add logging, run, read)
- Minimal reproduction (smallest failing case)
- Binary search (comment out half, narrow)
- Differential (compare working vs broken via git)
- Graph-assisted trace (follow GitNexus execution flow step by step)

**Graph-assisted trace:**

Instead of manually reading call chains, use GitNexus to walk the execution flow:
1. Read `gitnexus://repo/{name}/process/{processName}` for the step-by-step trace
2. At each step, read the actual code at that location
3. Check: does this transform data correctly?
4. The first node where output diverges from contract = root cause candidate

## Phase 5: Classify

Same severity levels as autoresearch:debug (Critical/High/Medium/Low).

**Added: Graph impact score**

For each confirmed bug, use the `impact` tool to measure blast radius:
- How many symbols depend on the buggy node? (depth 1, 2, 3)
- How many execution flows pass through it?
- Which communities (clusters) are affected?

```
graph_impact = dependents_count + (affected_flows * 2) + (affected_communities * 5)
```

This helps prioritize fixes: a Medium-severity bug with graph_impact=47 matters more
than a High-severity bug with graph_impact=3.

**Bug finding format:**
```
### [{SEVERITY}] Bug: {title} (impact: {graph_impact})
- Location: `file:line`
- Graph node: {symbol name from GitNexus}
- Dependents: {N} symbols, {M} flows, {P} communities
- Runtime signal: {log pattern that surfaced this, if any}
- Hypothesis: {what we suspected}
- Evidence: {code + experiment result}
- Root cause: {WHY it happens}
- Suggested fix: {concrete change}
```

Write each finding to `$OUTDIR/findings.md` as confirmed.
Write disproven hypotheses to `$OUTDIR/eliminated.md`.

## Phase 6: Log + Score

**Append to `$OUTDIR/eyeofhorus-results.tsv`:**
```tsv
iteration	type	hypothesis	result	severity	graph_impact	location	description
1	hypothesis	JWT skips alg	confirmed	CRITICAL	47	auth.ts:42	Algorithm confusion
2	hypothesis	Rate limit	disproven	-	-	-	Rate limiter exists
```

**Every 5 iterations, print progress + score:**
```
=== EyeofHorus Progress (iteration 10) ===
Bugs found: 3 (1 Critical, 1 High, 1 Medium)
Hypotheses tested: 8 (3 confirmed, 4 disproven, 1 inconclusive)
Graph coverage: 34/109 flows (31%)
Time to first bug: 47s

eyeofhorus_score = (3 * 10) + (31 * 0.4) + 10 = 52.4
```

**Composite metric:**
```
eyeofhorus_score = (bugs_found * 10) + (coverage_pct * 0.4) + speed_bonus
```

Speed bonus: 10 if first bug < 60s, 5 if < 120s, 0 otherwise.

Higher is better. Weights are initial estimates. Calibrate against FW-C after 5-10 runs.

**To compute the score**, run the scoring script:
```bash
bash references/eyeofhorus-score.sh "$OUTDIR"
```

## Phase 7: Hunt

**Next target selection (graph-powered):**

1. If a bug was just confirmed: use `impact` tool to follow its dependent chain. Are dependents also broken? (Cascading failure search)
2. Pattern match: use `query` tool to search the graph for nodes with the same anti-pattern as the confirmed bug
3. Move to the next priority target from the Phase 2 attack surface
4. If attack surface exhausted: read `gitnexus://repo/{name}/clusters` and expand to adjacent communities

**When to stop (unbounded):**
- Never stop automatically. User interrupts.
- Print diminishing returns warning after 5 iterations with no new findings.

**When to stop (bounded):**
- After N iterations, print final summary with score.

Write final summary to `$OUTDIR/summary.md`.

## Flags

| Flag | Purpose |
|------|---------|
| `--fix` | After finding bugs, chain to autoresearch:fix |
| `--scope <path>` | Target directory/repo |
| `--severity <level>` | Only report at or above this level |
| `--iterations N` | Bounded mode |
| `--reindex` | Force GitNexus reindex before scanning |

## Output Directory

Creates `eyeofhorus/{YYMMDD}-{HHMM}-{slug}/` with:
- `findings.md` -- confirmed bugs with evidence and graph impact
- `eliminated.md` -- disproven hypotheses
- `attack-surface.md` -- the Phase 2 map (preserved for replay)
- `eyeofhorus-results.tsv` -- iteration log
- `summary.md` -- final score, recommendations, coverage map

## Chaining

```
# Find bugs, then fix them
/eyeofhorus --fix

# Scan, then run PRISM on the findings
/eyeofhorus
/prism findings.md

# Scan after a deploy
/eyeofhorus --scope src/ --iterations 10
```

## Lineage

EyeofHorus descends from two parents:
- **autoresearch:debug** (scientific method, hypothesis loop, severity classification)
- **GitNexus** (graph intelligence, execution flows, impact analysis)

The synthesis: debug's rigor + graph's omniscience. Neither parent could do this alone.
Debug without the graph is blind to topology. The graph without debug is a map with no inspector.

Phase 1.5 (Runtime Overlay) is the third element: what the system actually does at runtime,
mapped back to the graph. Static analysis sees the code. Logs see the behavior. The overlay
connects them. Temporal correlation catches hidden dependencies the graph can't express.

## Scoring Calibration

After each run, the operator scores FW-C (1-10). Over time, correlate:
- Which weight (bugs, coverage, speed) predicts FW-C best?
- Adjust weights to maximize correlation with felt usefulness

Initial weights are placeholders. The data decides.

## Known Limitations

1. **GitNexus index can be stale.** If the codebase changed significantly since last index, Phase 2 may miss new files or report deleted ones. Use `--reindex` or check freshness first.
2. **Composite metric is uncalibrated.** Weights are initial guesses. Don't over-index on the score until 10+ runs have been correlated with FW-C.
3. **Coverage denominator is total flows, not relevant flows.** A codebase with 109 flows where only 20 are in scope will show low coverage even if all 20 are checked. Consider scope-adjusted coverage in future versions.
4. **Non-indexed targets degrade to autoresearch:debug.** If no GitNexus index exists, Phase 2 falls back to manual file scanning. The tool still works, but without graph intelligence.
