#!/bin/bash
# Validate a recorded WAV file has real audio content.
# Usage: ./ci/validate-audio.sh <wav-file> [min-duration-seconds]
# Exits 0 if valid, 1 if validation fails.

set -e

WAV_FILE="$1"
MIN_DURATION="${2:-10}"

if [ -z "$WAV_FILE" ]; then
  echo "Usage: $0 <wav-file> [min-duration-seconds]"
  exit 1
fi

PASS=true

echo "=== Audio Validation: $(basename "$WAV_FILE") ==="
echo ""

# 1. Check file exists
echo -n "  [1/4] File exists .................. "
if [ ! -f "$WAV_FILE" ]; then
  echo "FAIL (not found: $WAV_FILE)"
  exit 1
fi
echo "OK"

# 2. Check file size
FILE_SIZE=$(stat -f%z "$WAV_FILE" 2>/dev/null || stat -c%s "$WAV_FILE" 2>/dev/null)
echo -n "  [2/4] File size > 1KB .............. "
if [ "$FILE_SIZE" -lt 1000 ]; then
  echo "FAIL (${FILE_SIZE} bytes)"
  PASS=false
else
  echo "OK (${FILE_SIZE} bytes)"
fi

# 3. Check duration
DURATION=$(ffprobe -i "$WAV_FILE" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null)
DURATION_INT=$(printf "%.0f" "$DURATION" 2>/dev/null || echo 0)
echo -n "  [3/4] Duration >= ${MIN_DURATION}s .............. "
if [ -z "$DURATION" ]; then
  echo "FAIL (could not read duration)"
  PASS=false
elif [ "$DURATION_INT" -lt "$MIN_DURATION" ]; then
  echo "FAIL (${DURATION}s < ${MIN_DURATION}s)"
  PASS=false
else
  echo "OK (${DURATION}s)"
fi

# 4. Check volume (not silent)
MEAN_VOLUME=$(ffmpeg -i "$WAV_FILE" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
VOLUME_INT=$(printf "%.0f" "$MEAN_VOLUME" 2>/dev/null || echo -91)
echo -n "  [4/4] Mean volume > -60 dB ......... "
if [ -z "$MEAN_VOLUME" ]; then
  echo "FAIL (could not detect volume)"
  PASS=false
elif [ "$VOLUME_INT" -lt -60 ]; then
  echo "FAIL (${MEAN_VOLUME} dB — silent)"
  PASS=false
else
  echo "OK (${MEAN_VOLUME} dB)"
fi

echo ""
if [ "$PASS" = true ]; then
  echo "  RESULT: PASS"
else
  echo "  RESULT: FAIL"
  exit 1
fi
