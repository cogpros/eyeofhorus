#!/bin/bash
# overlay.sh — EyeofHorus Phase 1.5: one clock, every log.  [PORTABLE TEMPLATE]
#
# Emits ONE timezone-normalized, clock-ordered timeline across your machine's
# log surfaces for a time window. This is the instrument behind the skill's
# signature move: attribution by CLOCK when attribution by NAME fails.
#
# ── ADAPT THIS TO YOUR MACHINE ────────────────────────────────────────────────
# The value of this script is entirely in the SOURCE LIST and the CLOCK each
# source uses. Every deployment is different. Fill in LOCAL_UTC_OFFSET and the
# SOURCES block below with your own logs.
#
# THE TRAP THIS SCRIPT EXISTS TO ENCODE: a busy machine logs in MORE THAN ONE
# CLOCK. Some services stamp UTC ('...Z'), some stamp local (with or without an
# offset marker), and some (notably Go/gin servers) stamp local time with NO
# timezone marker at all. A naive time-bucket join across them returns an EMPTY
# correlation table that reads as "nothing happened" when it means "you compared
# 17:20 local to 23:20 UTC." Normalize EVERY source to UTC before merging.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Your local offset from UTC. If your region observes DST, this script needs a
# real tz library instead of a fixed offset — that is the #1 thing to get right.
LOCAL_UTC_OFFSET_HOURS=0     # e.g. 6 for a fixed UTC-6 zone with no DST

AROUND="" WINDOW=120 FROM="" TO="" GREP=""
while [ $# -gt 0 ]; do case "$1" in
  --around) AROUND="$2"; shift 2 ;; --window) WINDOW="$2"; shift 2 ;;
  --from) FROM="$2"; shift 2 ;; --to) TO="$2"; shift 2 ;;
  --grep) GREP="$2"; shift 2 ;; *) echo "unknown arg: $1" >&2; exit 2 ;;
esac; done
[ -n "$AROUND" ] || [ -n "$FROM" ] || { echo "need --around TS(UTC) or --from/--to" >&2; exit 2; }

python3 - "$AROUND" "$WINDOW" "$FROM" "$TO" "$GREP" "$LOCAL_UTC_OFFSET_HOURS" <<'PY'
import glob, json, os, re, sys
from datetime import datetime, timedelta, timezone
around, window, tfrom, tto, pat, off = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6])
LOCAL = timedelta(hours=off)
def putc(s):
    s = s.strip().replace("Z", "+00:00"); return datetime.fromisoformat(s).astimezone(timezone.utc)
c = putc(around) if around else None
lo, hi = (c - timedelta(seconds=window), c + timedelta(seconds=window)) if c else (putc(tfrom), putc(tto))
rows = []
def add(dt, src, detail):
    if lo <= dt <= hi:
        d = " ".join(str(detail).split())[:220]
        if not pat or re.search(pat, d, re.I): rows.append((dt, src, d))
def iso(s):
    try: return putc(s)
    except Exception: return None

# ── SOURCES — replace with your own. Three archetypes shown: ──────────────────
#
# (1) UTC-'Z' JSON-lines log (e.g. an event bus). Already UTC — no conversion.
#   p = os.path.expanduser("~/path/to/events.jsonl")
#   if os.path.exists(p):
#       for line in open(p, errors="replace"):
#           try: d = json.loads(line)
#           except Exception: continue
#           ts = iso(str(d.get("ts",""))); add(ts, "bus", d.get("event","")) if ts else None
#
# (2) ISO-with-offset text log (e.g. '2026-08-02T17:17:58.329-06:00 ...').
#   fromisoformat handles the offset; iso() returns correct UTC.
#
# (3) LOCAL-TIME, NO-TZ-MARKER log (the dangerous one — gin/Go servers:
#     '[GIN] 2026/08/02 - 19:51:07 | ...'). Parse as naive, then ADD LOCAL:
#   local = datetime.strptime(m.group(1), "%Y/%m/%d %H:%M:%S")
#   add(local.replace(tzinfo=timezone.utc) + LOCAL, "server", detail)
#   # ^ the '+ LOCAL' is the whole point. Omit it and this source lands 'off'
#   #   hours away from the UTC sources and correlates with nothing.
#
# Add one block per real log surface you have. When a hunt dead-ends, the first
# question is: is the actor logging somewhere NOT in this list?

rows.sort(key=lambda r: r[0])
if not rows:
    print("NO EVENTS IN WINDOW. Before concluding 'nothing happened': is --around "
          "in UTC? Did you add '+ LOCAL' to every no-marker source? Widen --window.", file=sys.stderr)
    sys.exit(1)
for dt, src, detail in rows:
    print(f"{dt.strftime('%Y-%m-%dT%H:%M:%S')}Z\t{src}\t{detail}")
print(f"\n# {len(rows)} events, {lo.strftime('%H:%M:%S')}Z -> {hi.strftime('%H:%M:%S')}Z, "
      f"sources={len(set(r[1] for r in rows))}", file=sys.stderr)
PY
