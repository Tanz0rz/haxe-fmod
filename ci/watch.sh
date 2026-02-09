#!/bin/bash
# Watch a GitHub Actions run until all jobs complete or one fails.
# Usage: ./ci-watch.sh [run-id]
# If no run-id given, uses the latest run.

set -o noglob

RUN_ID="${1:-$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')}"
echo "Watching run $RUN_ID"

while true; do
  jobs=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[] | "\(.name)|\(.status)|\(.conclusion // "")"' 2>&1)

  echo "=== $(date +%H:%M:%S) ==="
  echo "$jobs" | column -t -s'|'

  # Check for any failure
  if echo "$jobs" | grep -q "|completed|failure"; then
    echo ""
    echo "FAILURE DETECTED"
    # Show which jobs failed
    echo "$jobs" | grep "|completed|failure" | cut -d'|' -f1 | while read -r name; do
      echo "  FAILED: $name"
    done
    exit 1
  fi

  # Check if all jobs are done (no in_progress, queued, or waiting)
  still_running=$(echo "$jobs" | grep -cE "\|in_progress\||\|queued\||\|waiting\|" || true)
  if [ "$still_running" -eq 0 ] && [ -n "$jobs" ]; then
    echo ""
    echo "ALL JOBS COMPLETE"
    exit 0
  fi

  sleep 20
done
