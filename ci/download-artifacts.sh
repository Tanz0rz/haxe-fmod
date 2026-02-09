#!/bin/bash
# Download all audio artifacts from a GitHub Actions run into ci/artifacts/.
# Usage: ./ci/download-artifacts.sh [run-id]
# If no run-id given, uses the latest run.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"

RUN_ID="${1:-$(gh run list --status completed --limit 1 --json databaseId --jq '.[0].databaseId')}"
echo "Downloading artifacts from run $RUN_ID"

# Clean previous artifacts
rm -f "$ARTIFACTS_DIR"/*.wav

# Download all audio artifacts
for name in audio-linux-cpp audio-linux-hl audio-html5 audio-mac-cpp audio-mac-hl; do
  echo -n "  $name... "
  if gh run download "$RUN_ID" --name "$name" --dir "$ARTIFACTS_DIR" 2>/dev/null; then
    echo "ok"
  else
    echo "not found"
  fi
done

echo ""
echo "Artifacts in $ARTIFACTS_DIR:"
ls -lh "$ARTIFACTS_DIR"/*.wav 2>/dev/null || echo "  (none)"

# Show audio stats if ffprobe is available
if command -v ffprobe &>/dev/null; then
  echo ""
  echo "Audio analysis:"
  for wav in "$ARTIFACTS_DIR"/*.wav; do
    [ -f "$wav" ] || continue
    name=$(basename "$wav" .wav)
    duration=$(ffprobe -i "$wav" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null)
    volume=$(ffmpeg -i "$wav" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //')
    printf "  %-25s %6.1fs  mean: %s\n" "$name" "$duration" "$volume"
  done
fi
