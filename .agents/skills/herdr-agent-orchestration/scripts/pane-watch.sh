#!/bin/sh
# Usage: pane-watch.sh <pane-id> <done-file> [done-pattern]
# Exits when the pane shows a permission prompt (BLOCKED) or when the done file
# exists (and, if given, contains the pattern) (READY). Polls every 20s.
pane="$1"; done_file="$2"; pattern="$3"
while :; do
  screen=$(herdr pane read "$pane" --source visible --lines 40 2>/dev/null)
  if printf '%s' "$screen" | grep -q "Permission Required"; then
    echo "BLOCKED $pane"
    printf '%s\n' "$screen" | grep -A3 -E "^tool|^input" | head -8
    exit 0
  fi
  if [ -f "$done_file" ]; then
    if [ -z "$pattern" ] || grep -q "$pattern" "$done_file"; then
      sleep 45; echo "READY $done_file"; exit 0
    fi
  fi
  sleep 20
done
