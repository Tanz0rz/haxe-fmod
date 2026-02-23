#!/bin/bash
# Validate a volume test WAV file has correct volume phases.
# Usage: ./ci/validate-volume.sh <wav-file> [total-duration-seconds]
#
# The volume test records 3 phases:
#   Phase 1 (0-10s): Full volume
#   Phase 2 (10-20s): Volume at 10%
#   Phase 3 (20-30s): Muted
#
# Exits 0 if valid, 1 if validation fails.

WAV_FILE="$1"
TOTAL_DURATION="${2:-30}"

# Resolve ffprobe/ffmpeg commands (may need explicit paths on Windows)
FFPROBE="ffprobe"
FFMPEG="ffmpeg"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  for dir in "/c/ProgramData/chocolatey/bin" /c/ProgramData/chocolatey/lib/ffmpeg/tools/*/bin; do
    if [ -x "$dir/ffprobe.exe" ]; then
      FFPROBE="$dir/ffprobe.exe"
      FFMPEG="$dir/ffmpeg.exe"
      break
    fi
  done
  echo "  Using: $FFPROBE"
fi

if [ -z "$WAV_FILE" ]; then
  echo "Usage: $0 <wav-file> [total-duration-seconds]"
  exit 1
fi

PASS=true
SEGMENT=$((TOTAL_DURATION / 3))

echo "=== Volume Test Validation: $(basename "$WAV_FILE") ==="
echo ""

# Check file exists
echo -n "  [0/3] File exists .................. "
if [ ! -f "$WAV_FILE" ]; then
  echo "FAIL (not found: $WAV_FILE)"
  exit 1
fi
echo "OK"

# Helper: get mean volume for a segment of the WAV file
# Falls back to raw PCM input if WAV header is malformed
get_segment_volume() {
  local start="$1"
  local duration="$2"
  local vol
  vol=$("$FFMPEG" -i "$WAV_FILE" -ss "$start" -t "$duration" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
  if [ -z "$vol" ]; then
    vol=$("$FFMPEG" -f s16le -ar 48000 -ac 2 -i "$WAV_FILE" -ss "$start" -t "$duration" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
  fi
  echo "$vol"
}

# Phase 1: Full volume (0 to SEGMENT)
VOL1=$(get_segment_volume 0 "$SEGMENT")
VOL1_INT=$(printf "%.0f" "$VOL1" 2>/dev/null || echo -91)
echo -n "  [1/3] Phase 1 (full) > -40 dB ...... "
if [ -z "$VOL1" ]; then
  echo "FAIL (could not detect volume)"
  PASS=false
elif [ "$VOL1_INT" -lt -40 ]; then
  echo "FAIL (${VOL1} dB - too quiet for full volume)"
  PASS=false
else
  echo "OK (${VOL1} dB)"
fi

# Phase 2: Volume at 10% (SEGMENT to 2*SEGMENT)
VOL2=$(get_segment_volume "$SEGMENT" "$SEGMENT")
VOL2_INT=$(printf "%.0f" "$VOL2" 2>/dev/null || echo -91)
echo -n "  [2/3] Phase 2 (10%) > -60 dB ....... "
if [ -z "$VOL2" ]; then
  echo "FAIL (could not detect volume)"
  PASS=false
elif [ "$VOL2_INT" -lt -60 ]; then
  echo "FAIL (${VOL2} dB - too quiet for 10% volume)"
  PASS=false
else
  echo -n "OK (${VOL2} dB)"
  # Also check that phase 2 is quieter than phase 1
  if [ "$VOL2_INT" -ge "$VOL1_INT" ]; then
    echo " - WARN: not quieter than phase 1 (${VOL1} dB)"
    PASS=false
  else
    echo " - quieter than phase 1"
  fi
fi

# Phase 3: Muted (2*SEGMENT to 3*SEGMENT)
START3=$((SEGMENT * 2))
VOL3=$(get_segment_volume "$START3" "$SEGMENT")
VOL3_INT=$(printf "%.0f" "$VOL3" 2>/dev/null || echo -91)
echo -n "  [3/3] Phase 3 (muted) < -60 dB ..... "
if [ -z "$VOL3" ]; then
  echo "FAIL (could not detect volume)"
  PASS=false
elif [ "$VOL3_INT" -ge -60 ]; then
  echo "FAIL (${VOL3} dB - not silent enough for muted)"
  PASS=false
else
  echo "OK (${VOL3} dB)"
fi

echo ""
if [ "$PASS" = true ]; then
  echo "  RESULT: PASS"
else
  echo "  RESULT: FAIL"
  exit 1
fi
