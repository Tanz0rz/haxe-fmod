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

echo "=== Audio Validation: $(basename "$WAV_FILE") ==="

# Check file exists
if [ ! -f "$WAV_FILE" ]; then
  echo "FAIL: File does not exist: $WAV_FILE"
  exit 1
fi

# Check file is not empty
FILE_SIZE=$(stat -f%z "$WAV_FILE" 2>/dev/null || stat -c%s "$WAV_FILE" 2>/dev/null)
if [ "$FILE_SIZE" -lt 1000 ]; then
  echo "FAIL: File too small (${FILE_SIZE} bytes)"
  exit 1
fi

# Get duration
DURATION=$(ffprobe -i "$WAV_FILE" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null)
if [ -z "$DURATION" ]; then
  echo "FAIL: Could not read duration (corrupt file?)"
  exit 1
fi

# Compare duration (integer comparison)
DURATION_INT=$(printf "%.0f" "$DURATION")
if [ "$DURATION_INT" -lt "$MIN_DURATION" ]; then
  echo "FAIL: Duration ${DURATION}s is below minimum ${MIN_DURATION}s"
  exit 1
fi

# Get mean volume
MEAN_VOLUME=$(ffmpeg -i "$WAV_FILE" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
if [ -z "$MEAN_VOLUME" ]; then
  echo "FAIL: Could not detect volume (corrupt file?)"
  exit 1
fi

# Check not silent (mean volume should be above -60 dB)
# Volume is negative, so we check if it's greater than -60 (i.e., louder)
VOLUME_INT=$(printf "%.0f" "$MEAN_VOLUME")
if [ "$VOLUME_INT" -lt -60 ]; then
  echo "FAIL: Audio is silent (mean volume: ${MEAN_VOLUME} dB)"
  exit 1
fi

echo "  Duration: ${DURATION}s (min: ${MIN_DURATION}s)"
echo "  Volume:   ${MEAN_VOLUME} dB"
echo "  Size:     ${FILE_SIZE} bytes"
echo "PASS"
