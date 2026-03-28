# GitNexus Query Templates for EyeofHorus

Quick reference for the actual GitNexus MCP tools and resources used in each phase.

## Tools (active queries)

| Tool | What it does | EyeofHorus phase |
|------|-------------|------------------|
| `query` | Process-grouped code intelligence. Find execution flows related to a concept. | Phase 2 (map error signals), Phase 7 (pattern search) |
| `context` | 360-degree symbol view. Callers, callees, processes it participates in. | Phase 2 (map dependencies), Phase 3 (hypothesis formation) |
| `impact` | Symbol blast radius at depth 1/2/3 with confidence scores. | Phase 2 (fan-out ranking), Phase 5 (graph impact score), Phase 7 (cascading failure) |
| `detect_changes` | Git-diff impact. What do current uncommitted changes affect? | Phase 1 (recent change correlation) |
| `cypher` | Raw graph queries. Use when tools above don't cover the question. | Phase 3 (verify no path between correlated nodes) |
| `list_repos` | Discover indexed repos. | Prerequisites check |

## Resources (lightweight reads)

| Resource | What it returns | EyeofHorus phase |
|----------|----------------|------------------|
| `gitnexus://repo/{name}/context` | Stats, staleness check | Prerequisites, Phase 2 Step 1 |
| `gitnexus://repo/{name}/clusters` | All functional areas with cohesion scores | Phase 2 (community structure), Phase 7 (expand to adjacent) |
| `gitnexus://repo/{name}/cluster/{clusterName}` | Members of a specific cluster | Phase 3 (cross-boundary investigation) |
| `gitnexus://repo/{name}/processes` | All execution flows | Phase 2 Step 2 (coverage denominator) |
| `gitnexus://repo/{name}/process/{processName}` | Step-by-step trace of one flow | Phase 4 (graph-assisted trace) |
| `gitnexus://repo/{name}/schema` | Graph schema for Cypher queries | Phase 3 (custom queries) |

## Common Query Patterns

### Find all symbols related to an error keyword
```
Tool: query
Input: { "repo": "{name}", "query": "error keyword here" }
```

### Get blast radius of a buggy function
```
Tool: impact
Input: { "repo": "{name}", "symbol": "functionName", "depth": 3 }
```

### Check if two nodes are connected (temporal correlation verification)
```
Tool: cypher
Input: {
  "repo": "{name}",
  "query": "MATCH path = shortestPath((a:Function {name: 'nodeA'})-[*]-(b:Function {name: 'nodeB'})) RETURN path"
}
```
If no path returned, the temporal correlation represents a hidden dependency.

### List all execution flows through a file
```
Tool: context
Input: { "repo": "{name}", "symbol": "filename.ts" }
```
Look at the "processes" section of the response.

### Expand investigation to adjacent cluster
```
Resource: gitnexus://repo/{name}/clusters
```
Find the cluster containing current investigation targets. Read adjacent clusters for expansion.

## Graph Schema Quick Reference

**Nodes:** File, Function, Class, Interface, Method, Community, Process
**Edges (CodeRelation.type):** CALLS, IMPORTS, EXTENDS, IMPLEMENTS, DEFINES, MEMBER_OF, STEP_IN_PROCESS

## Repo Names

The `{name}` in all queries is the repo name as indexed by GitNexus.
Use `list_repos` tool to discover available repo names on your system.
