#!/bin/bash
# Download all audio artifacts from a GitHub Actions run into ci/artifacts/.
# Usage: ./ci/download-artifacts.sh [run-id]
# If no run-id given, uses the latest completed run.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"

RUN_ID="${1:-$(gh run list --status completed --limit 1 --json databaseId --jq '.[0].databaseId')}"
echo "Downloading artifacts from run $RUN_ID"
echo ""

# Clean previous artifacts
rm -rf "$ARTIFACTS_DIR"
mkdir -p "$ARTIFACTS_DIR"

# Download all artifacts
ARTIFACT_NAMES=(audio-linux-cpp audio-linux-hl audio-html5 audio-mac-cpp audio-mac-hl audio-windows-cpp audio-windows-hl)
for name in "${ARTIFACT_NAMES[@]}"; do
  echo -n "  $name... "
  if gh run download "$RUN_ID" --name "$name" --dir "$ARTIFACTS_DIR/$name" 2>/dev/null; then
    echo "ok"
  else
    echo "not found"
  fi
done

# Flatten: move files from subdirs to top level with clear names
for name in "${ARTIFACT_NAMES[@]}"; do
  dir="$ARTIFACTS_DIR/$name"
  [ -d "$dir" ] || continue

  # Move WAV files (may be in subdir or at root depending on upload path)
  find "$dir" -name "*.wav" -exec mv {} "$ARTIFACTS_DIR/${name}.wav" \; 2>/dev/null

  # Move game logs
  find "$dir" -name "*.log" -exec mv {} "$ARTIFACTS_DIR/${name}.log" \; 2>/dev/null

  # Clean up empty subdirs
  rm -rf "$dir"
done

echo ""
echo "=== Downloaded Files ==="
echo ""

# Show WAV files with audio stats
echo "Audio files:"
for wav in "$ARTIFACTS_DIR"/*.wav; do
  [ -f "$wav" ] || continue
  name=$(basename "$wav" .wav)
  size=$(ls -lh "$wav" | awk '{print $5}')

  if command -v ffprobe &>/dev/null; then
    duration=$(ffprobe -i "$wav" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null)
    volume=$(ffmpeg -i "$wav" -af volumedetect -f null /dev/null 2>&1 | grep mean_volume | sed 's/.*mean_volume: //')
    printf "  %-25s %6s  %6.1fs  mean: %s\n" "$name" "$size" "$duration" "$volume"
  else
    printf "  %-25s %6s\n" "$name" "$size"
  fi
done

# Show game logs
echo ""
echo "Game logs:"
FOUND_LOGS=false
for log in "$ARTIFACTS_DIR"/*.log; do
  [ -f "$log" ] || continue
  FOUND_LOGS=true
  name=$(basename "$log")
  lines=$(wc -l < "$log" | tr -d ' ')
  if [ "$lines" -eq 0 ]; then
    printf "  %-30s (empty - no errors)\n" "$name"
  else
    printf "  %-30s (%s lines)\n" "$name" "$lines"
  fi
done
$FOUND_LOGS || echo "  (none)"

echo ""
echo "Files saved to: $ARTIFACTS_DIR/"
