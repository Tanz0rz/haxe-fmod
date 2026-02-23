#!/bin/bash
# Validate a volume test WAV file has correct volume phases.
# Usage: ./ci/validate-volume.sh <wav-file> [total-duration-seconds]
#
# The volume test records 3 phases:
#   Phase 1 (0-5s): Full volume
#   Phase 2 (5-10s): Volume at 30%
#   Phase 3 (10-15s): Muted
#
# Samples a 2-second window at the CENTER of each phase
# to avoid phase transition boundaries.
#
# Exits 0 if valid, 1 if validation fails.

WAV_FILE="$1"
TOTAL_DURATION="${2:-15}"

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
SAMPLE_DURATION=2

# Center of each phase: 5s, 15s, 25s (with 30s total, 10s segments)
MID1=$(( SEGMENT / 2 ))
MID2=$(( SEGMENT + SEGMENT / 2 ))
MID3=$(( SEGMENT * 2 + SEGMENT / 2 ))

echo "=== Volume Test Validation: $(basename "$WAV_FILE") ==="
echo "  Sampling ${SAMPLE_DURATION}s windows at ${MID1}s, ${MID2}s, ${MID3}s"
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
  vol=$("$FFMPEG" -ss "$start" -t "$duration" -i "$WAV_FILE" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
  if [ -z "$vol" ]; then
    vol=$("$FFMPEG" -ss "$start" -t "$duration" -f s16le -ar 48000 -ac 2 -i "$WAV_FILE" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
  fi
  echo "$vol"
}

# Phase 1: Full volume (sample at center)
VOL1=$(get_segment_volume "$MID1" "$SAMPLE_DURATION")
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

# Phase 2: Volume at 30% (sample at center)
VOL2=$(get_segment_volume "$MID2" "$SAMPLE_DURATION")
VOL2_INT=$(printf "%.0f" "$VOL2" 2>/dev/null || echo -91)
echo -n "  [2/3] Phase 2 (30%) > -60 dB ....... "
if [ -z "$VOL2" ]; then
  echo "FAIL (could not detect volume)"
  PASS=false
elif [ "$VOL2_INT" -lt -60 ]; then
  echo "FAIL (${VOL2} dB - too quiet for 30% volume)"
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

# Phase 3: Muted (sample at center)
VOL3=$(get_segment_volume "$MID3" "$SAMPLE_DURATION")
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
