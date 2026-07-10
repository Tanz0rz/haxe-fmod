#!/bin/bash
# Validate a recorded WAV file has real audio content.
# Usage: ./ci/validate-audio.sh <wav-file> [min-duration-seconds]
# Exits 0 if valid, 1 if validation fails.

WAV_FILE="$1"
MIN_DURATION="${2:-10}"

# Resolve ffprobe/ffmpeg commands (may need explicit paths on Windows)
FFPROBE="ffprobe"
FFMPEG="ffmpeg"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  # On Windows/Git Bash, find ffprobe from choco install locations
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
  echo "Usage: $0 <wav-file> [min-duration-seconds]"
  exit 1
fi

PASS=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Audio Validation: $(basename "$WAV_FILE") ==="
echo ""

# 1. Check file exists
echo -n "  [1/5] File exists .................. "
if [ ! -f "$WAV_FILE" ]; then
  echo "FAIL (not found: $WAV_FILE)"
  exit 1
fi
echo "OK"

# 2. Check file size
FILE_SIZE=$(stat -f%z "$WAV_FILE" 2>/dev/null || stat -c%s "$WAV_FILE" 2>/dev/null || wc -c < "$WAV_FILE")
echo -n "  [2/5] File size > 1KB .............. "
if [ "$FILE_SIZE" -lt 1000 ]; then
  echo "FAIL (${FILE_SIZE} bytes)"
  PASS=false
else
  echo "OK (${FILE_SIZE} bytes)"
fi

# 3. Check duration
# Try normal probe first. If WAV header is malformed (e.g. FMOD WAVWRITER on Windows
# writes 0 channels), fall back to raw PCM interpretation (s16le, 48kHz, stereo).
DURATION=$("$FFPROBE" -i "$WAV_FILE" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null)
if [ -z "$DURATION" ] || [ "$DURATION" = "N/A" ]; then
  # Malformed WAV header - compute duration from file size assuming 48kHz 16-bit stereo
  # bytes = duration * 48000 * 2 channels * 2 bytes/sample = duration * 192000
  DURATION=$(awk "BEGIN {printf \"%.1f\", ($FILE_SIZE - 44) / 192000.0}")
fi
DURATION_INT=$(printf "%.0f" "$DURATION" 2>/dev/null || echo 0)
echo -n "  [3/5] Duration >= ${MIN_DURATION}s .............. "
if [ -z "$DURATION" ]; then
  echo "FAIL (could not read duration)"
  PASS=false
elif [ "$DURATION_INT" -lt "$MIN_DURATION" ]; then
  echo "FAIL (${DURATION}s < ${MIN_DURATION}s)"
  PASS=false
else
  echo "OK (${DURATION}s)"
fi

# Resolve a Python interpreter (python3 on Linux/Mac, python on Windows)
PYTHON="python3"
command -v python3 >/dev/null 2>&1 || PYTHON="python"

# 4. Check volume (not silent)
# Try normal ffmpeg volumedetect. If WAV header is malformed, use raw PCM input
MEAN_VOLUME=$("$FFMPEG" -i "$WAV_FILE" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
if [ -z "$MEAN_VOLUME" ]; then
  MEAN_VOLUME=$("$FFMPEG" -f s16le -ar 48000 -ac 2 -i "$WAV_FILE" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //' | sed 's/ dB//')
fi
VOLUME_INT=$(printf "%.0f" "$MEAN_VOLUME" 2>/dev/null || echo -91)
echo -n "  [4/5] Mean volume > -60 dB ......... "
if [ -z "$MEAN_VOLUME" ]; then
  echo "FAIL (could not detect volume)"
  PASS=false
elif [ "$VOLUME_INT" -lt -60 ]; then
  echo "FAIL (${MEAN_VOLUME} dB - silent)"
  PASS=false
else
  echo "OK (${MEAN_VOLUME} dB)"
fi

# 5. Deep profile of the active region: enough active audio, no dropout
# gaps, both channels alive, bounded leading silence, no sustained clipping.
# The whole-file mean-volume check above cannot see any of these.
echo "  [5/5] Active-region profile ........"
if "$PYTHON" "$SCRIPT_DIR/audio-profile.py" "$WAV_FILE" --min-active "$MIN_DURATION"; then
  echo "        OK"
else
  echo "        FAIL (see profile above)"
  PASS=false
fi

echo ""
if [ "$PASS" = true ]; then
  echo "  RESULT: PASS"
else
  echo "  RESULT: FAIL"
  exit 1
fi
