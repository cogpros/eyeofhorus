#!/usr/bin/env bash
# EyeofHorus composite scoring script
# Usage: eyeofhorus-score.sh <output-dir>
#
# Reads eyeofhorus-results.tsv from the output directory,
# computes the composite metric, prints the score.

set -euo pipefail

OUTDIR="${1:?Usage: eyeofhorus-score.sh <output-dir>}"
TSV="$OUTDIR/eyeofhorus-results.tsv"

if [[ ! -f "$TSV" ]]; then
  echo "No results file found at $TSV" >&2
  exit 1
fi

# Count confirmed bugs
BUGS=$(awk -F'\t' '$4 == "confirmed" { count++ } END { print count+0 }' "$TSV")

# Count total hypotheses tested
HYPOTHESES=$(awk -F'\t' 'NR > 1 && $2 == "hypothesis" { count++ } END { print count+0 }' "$TSV")

# Coverage: read from attack-surface.md if it exists
COVERAGE=0
ATTACK="$OUTDIR/attack-surface.md"
if [[ -f "$ATTACK" ]]; then
  # Look for "coverage_pct:" or "X% flow coverage" pattern
  COVERAGE=$(grep -oE '[0-9]+\.?[0-9]*% flow coverage' "$ATTACK" | head -1 | grep -oE '[0-9]+\.?[0-9]*' || echo "0")
fi

# Time to first bug: check timestamps in TSV
# First line after header with result=confirmed
FIRST_BUG_TIME=""
if [[ -f "$OUTDIR/.start_time" ]]; then
  START=$(cat "$OUTDIR/.start_time")
  FIRST_CONFIRMED=$(awk -F'\t' '$4 == "confirmed" { print NR; exit }' "$TSV")
  if [[ -n "$FIRST_CONFIRMED" && -f "$OUTDIR/.first_bug_time" ]]; then
    FIRST_BUG_TIME=$(cat "$OUTDIR/.first_bug_time")
    ELAPSED=$(( FIRST_BUG_TIME - START ))
  fi
fi

# Speed bonus
SPEED_BONUS=0
if [[ -n "$FIRST_BUG_TIME" ]]; then
  if (( ELAPSED < 60 )); then
    SPEED_BONUS=10
  elif (( ELAPSED < 120 )); then
    SPEED_BONUS=5
  fi
fi

# Composite score
SCORE=$(python3 -c "
bugs = $BUGS
coverage = $COVERAGE
speed = $SPEED_BONUS
score = (bugs * 10) + (coverage * 0.4) + speed
print(f'{score:.1f}')
")

echo "=== EyeofHorus Score ==="
echo "Bugs found:        $BUGS"
echo "Hypotheses tested: $HYPOTHESES"
echo "Graph coverage:    ${COVERAGE}%"
echo "Speed bonus:       $SPEED_BONUS"
echo "========================"
echo "eyeofhorus_score = ($BUGS * 10) + ($COVERAGE * 0.4) + $SPEED_BONUS = $SCORE"
echo ""
echo "Score: $SCORE"
