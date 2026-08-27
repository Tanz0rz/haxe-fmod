#!/bin/bash
# Validates the synth-test recording (see SynthTestState.hx): the frequency
# gate in audio-profile.py must see the 440/880/1320 tone sequence, proving
# Haxe-generated PCM and channel pitch control reach the audio output.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAV_FILE="$1"

echo "=== Synth audio validation: $WAV_FILE ==="
if [ -z "$WAV_FILE" ] || [ ! -f "$WAV_FILE" ]; then
  echo "FAIL: synth recording not found"
  exit 1
fi

PYTHON="python3"
command -v python3 >/dev/null 2>&1 || PYTHON="python"
"$PYTHON" "$SCRIPT_DIR/audio-profile.py" "$WAV_FILE" --synth
