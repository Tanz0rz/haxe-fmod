#!/bin/bash
# Validate that a game log has no FMOD errors.
# Usage: ./ci/validate-game-log.sh <log-file>
# Exits 0 if clean, 1 if errors found.

LOG_FILE="$1"

echo "=== Game Log Validation: $(basename "$LOG_FILE") ==="
echo ""

# 1. Check file exists
echo -n "  [1/3] Log file exists .............. "
if [ ! -f "$LOG_FILE" ]; then
  echo "FAIL (not found: $LOG_FILE)"
  exit 1
fi
echo "OK"

# 2. Check log is not empty (debug messages should be present)
LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo -n "  [2/3] Log has content .............. "
if [ "$LINES" -eq 0 ]; then
  echo "FAIL (empty — no FMOD debug output captured)"
  exit 1
fi
echo "OK ($LINES lines)"

# 3. Check for error indicators
echo -n "  [3/3] No FMOD errors ............... "
ERRORS=$(grep -iE "(Failed|Error|error|FMOD_ERR)" "$LOG_FILE" || true)
if [ -n "$ERRORS" ]; then
  echo "FAIL"
  echo ""
  echo "  Errors found:"
  echo "$ERRORS" | sed 's/^/    /'
  echo ""
  echo "  RESULT: FAIL"
  exit 1
fi
echo "OK"

echo ""
echo "  RESULT: PASS"
