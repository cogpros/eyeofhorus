# EyeofHorus

Graph-powered autonomous bug hunter for Claude Code. Combines GitNexus codebase intelligence with scientific debugging methodology. Sees the whole system at once, then proves what's broken.

Named for the Eye of Horus (Wadjet). The eye that was shattered in battle and rebuilt by Thoth. It saw deeper after the damage than before.

## What It Does

EyeofHorus scans an entire codebase for bugs using a 7-phase loop:

1. **Gather** signals from logs, tests, linters, git history
2. **Overlay** runtime data onto the code graph (temporal correlation, error frequency)
3. **Map** the attack surface using GitNexus (execution flows, dependencies, blast radius)
4. **Hypothesize** using graph topology, not guesses
5. **Test** each hypothesis with one atomic experiment
6. **Classify** severity + graph impact score
7. **Hunt** the next target using pattern matching across the graph

It keeps going until you stop it or it runs out of things to find.

## Prerequisites

### GitNexus MCP

EyeofHorus uses [GitNexus](https://github.com/githubnext/gitnexus) as its knowledge graph. GitNexus indexes your codebase into a graph of symbols, relationships, and execution flows that EyeofHorus queries during reconnaissance.

**Install GitNexus:**

```bash
npm install -g gitnexus
```

**Index your codebase:**

```bash
cd /path/to/your/project
npx gitnexus analyze
```

This creates a `.gitnexus/` directory with the graph database. EyeofHorus reads this via MCP (Model Context Protocol) tools.

**Add GitNexus MCP to your Claude Code config:**

In your project's `.claude/settings.json` or global `~/.claude/settings.json`, add GitNexus as an MCP server. Refer to the [GitNexus MCP documentation](https://github.com/githubnext/gitnexus) for the exact configuration.

### Claude Code

EyeofHorus is a Claude Code skill. You need [Claude Code](https://claude.ai/code) installed.

## Install

Copy the skill into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills/eyeofhorus
cp SKILL.md ~/.claude/skills/eyeofhorus/
cp -r references ~/.claude/skills/eyeofhorus/
```

Claude Code will auto-discover the skill on next session start.

## Usage

```
/eyeofhorus
```

With flags:

```
/eyeofhorus --scope ./src/ --severity high --fix
/eyeofhorus --scope ./my-project/ --iterations 20
```

### Flags

| Flag | Purpose |
|------|---------|
| `--fix` | After finding bugs, chain to autoresearch:fix to repair them |
| `--scope <path>` | Target directory or repo |
| `--severity <level>` | Only report at or above this level (critical/high/medium/low) |
| `--iterations N` | Stop after N iterations |
| `--reindex` | Force GitNexus reindex before scanning |

## How It Works

### Phase 1.5: Runtime Overlay

This is what makes EyeofHorus different from a static analyzer. It parses your logs, maps error events to graph nodes, and detects **temporal correlations**: two components that fail together repeatedly, even if the code shows no direct connection between them. Hidden dependencies that only appear at runtime.

### Phase 2: Graph Reconnaissance

Instead of grepping through files, EyeofHorus queries the GitNexus knowledge graph:
- `query` tool to find symbols related to error signals
- `impact` tool to measure blast radius of affected nodes
- `context` tool for 360-degree views of suspicious symbols
- Execution flow traces to walk through code paths step by step

### Composite Metric

Each run produces a score:

```
eyeofhorus_score = (bugs_found * 10) + (coverage_pct * 0.4) + speed_bonus
```

- **bugs_found**: confirmed bugs with evidence
- **coverage_pct**: percentage of execution flows investigated
- **speed_bonus**: 10 if first bug found in under 60s, 5 if under 120s, 0 otherwise

Higher is better. Weights are initial estimates, designed to be calibrated over time.

## Output

Each run creates a directory with:
- `findings.md`: confirmed bugs with evidence, severity, and graph impact
- `eliminated.md`: disproven hypotheses (equally valuable)
- `attack-surface.md`: the Phase 2 map
- `eyeofhorus-results.tsv`: raw iteration log
- `summary.md`: final score and recommendations

## Without GitNexus

EyeofHorus degrades gracefully. Without a GitNexus index, Phase 2 falls back to manual file scanning (essentially autoresearch:debug). The tool still works, but without graph intelligence. You lose execution flow tracing, blast radius scoring, and pattern matching across the graph.

## License

MIT

## Author

Dustin Pollock / [Raven Systems](https://github.com/cogpros)
