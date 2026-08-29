#!/bin/bash
# Replays the Linux jobs of .github/workflows/audio-test.yml on this machine.
# Every gate is the same script or grep the workflow uses, so a green run
# here means the same steps will be green on the runner. The Mac and
# Windows jobs have no local equivalent.
#
# Usage: ci/local-ci.sh [job ...]
#   jobs: unit-tests linux-cpp linux-hl linux-html5-chromium linux-html5-firefox
#         heaps-hl heaps-js kha-linux kha-hl kha-html5
#   no argument runs all of them
#
# Environment:
#   FMOD_SDK_ROOT  directory holding the linux/ and html5/ FMOD packages
#                  (default: the fmod-sdk-cache checkout next to this repo)
#   CHROMIUM       chromium binary (default: chromium-browser, then chromium)
#   KHA            a Kha checkout with submodules (kha jobs). Default: ../Kha
#   NODE_PATH      where the playwright package resolves from (firefox job).
#                  PLAYWRIGHT_BROWSERS_PATH is inherited, the image sets it
#
# Needs: haxe, haxelib with lime/openfl/flixel/hxcpp and haxefmod pointing
# at this checkout, hl, gcc, g++, python3, node, Xvfb, pulseaudio, ffmpeg,
# xdotool, readelf, a chromium, and the playwright firefox build.
#
# Output lands in ci/local/ (gitignored): one directory per job with every
# log and wav the workflow would have uploaded as an artifact.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/ci/local"
EXAMPLE="$ROOT/example-project/EZPlatformer"
FMOD_SDK_ROOT="${FMOD_SDK_ROOT:-$ROOT/../fmod-sdk-cache/sdk/2.03.12}"
CHROMIUM="${CHROMIUM:-$(command -v chromium-browser || command -v chromium || true)}"
# The html5 build a browser step serves, and the GL flags for it. Heaps needs
# WebGL, which a display-less chromium only has through SwiftShader.
WEB_BIN="$EXAMPLE/export/html5/bin"
CHROME_GL="--disable-gpu"
HEAPS="$ROOT/example-project/HeapsPlatformer"
KHAP="$ROOT/example-project/KhaPlatformer"
export KHA="${KHA:-$ROOT/../Kha}"
export NODE_PATH="${NODE_PATH:-/opt/playwright/node_modules}"
export HXCPP_COMPILE_CACHE="$OUT/hxcpp-cache"
export HXCPP_CACHE_MB=4000

JOBS=("$@")
[ ${#JOBS[@]} -eq 0 ] && JOBS=(unit-tests linux-cpp linux-hl linux-html5-chromium linux-html5-firefox heaps-hl heaps-js kha-linux kha-hl kha-html5)

mkdir -p "$OUT"
FAILED_STEPS=()
PASSED=0
CURRENT_JOB=""
TMP=""

# ---------------------------------------------------------------- helpers

# Runs one workflow step in a subshell. A failure is recorded and the job
# carries on, the way the workflow's !cancelled() steps do.
step() {
  local name="$1"; shift
  echo ""
  echo "=== [$CURRENT_JOB] $name"
  local rc=0
  ( set -e -o pipefail; cd "$ROOT"; "$@" ) || rc=$?
  if [ $rc -eq 0 ]; then
    PASSED=$((PASSED + 1))
  else
    echo "--- FAILED: [$CURRENT_JOB] $name (exit $rc)"
    FAILED_STEPS+=("[$CURRENT_JOB] $name")
  fi
  return 0
}

begin_job() {
  CURRENT_JOB="$1"
  TMP="$OUT/$1"
  rm -rf "$TMP"
  mkdir -p "$TMP"
  echo ""
  echo "################ $1"
}

require_sdk() {
  export FMOD_SDK="$FMOD_SDK_ROOT/linux"
  export FMOD_SDK_WEB="$FMOD_SDK_ROOT/html5"
  [ -f "$FMOD_SDK/api/core/inc/fmod_common.h" ] || { echo "no desktop FMOD SDK at $FMOD_SDK (set FMOD_SDK_ROOT)"; exit 1; }
  [ -f "$FMOD_SDK_WEB/api/studio/lib/wasm/fmodstudio.js" ] || { echo "no html5 FMOD SDK at $FMOD_SDK_WEB (set FMOD_SDK_ROOT)"; exit 1; }
}

# The workflow's Xvfb plus PulseAudio null sink. PulseAudio needs a runtime
# directory it owns, which a container's /run/user is usually not.
DISPLAY_STARTED=""
start_display_audio() {
  export DISPLAY=:99
  if [ -z "$DISPLAY_STARTED" ]; then
    Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
    DISPLAY_STARTED=$!
    sleep 1
  fi
  export XDG_RUNTIME_DIR="$OUT/xdg"
  export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
  pulseaudio --check 2>/dev/null || pulseaudio --start --exit-idle-time=-1 > /dev/null 2>&1 || true
  pactl list short sinks 2>/dev/null | grep -q virtual_speaker \
    || pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=VirtualSpeaker > /dev/null
  pactl set-default-sink virtual_speaker
  # FMOD opens ALSA, so the default ALSA device has to be the pulse bridge
  if [ ! -f ~/.asoundrc ]; then
    printf 'pcm.!default {\n  type pulse\n}\nctl.!default {\n  type pulse\n}\n' > ~/.asoundrc
  fi
}

cleanup() {
  [ -n "$DISPLAY_STARTED" ] && kill "$DISPLAY_STARTED" 2>/dev/null
  XDG_RUNTIME_DIR="$OUT/xdg" PULSE_RUNTIME_PATH="$OUT/xdg/pulse" pulseaudio --kill 2>/dev/null
  true
}
trap cleanup EXIT

# The game executable in a bin dir, the way the composite action finds it
find_exe() {
  local exe
  exe=$(find . -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "*.sh" ! -name "*.dat" -print -quit)
  if [ -z "$exe" ] && [ -f run.sh ]; then exe=./run.sh; fi
  echo "$exe"
}

# .github/actions/run-test-state, with the same arguments
# run_native_state <state> <gate> <bin-dir> <log> [timeout] [extra-gate] [copy-jump-wav] [use-wavwriter]
run_native_state() {
  local state="$1" gate="$2" bin_glob="$3" log="$4" tmo="${5:-30}" extra="${6:-}" jump="${7:-false}" wav="${8:-false}"
  local bin
  bin=$(ls -d $bin_glob 2>/dev/null | head -1 || true)
  [ -n "$bin" ] || { echo "No bin directory matched: $bin_glob"; return 1; }
  if [ "$jump" = "true" ]; then
    mkdir -p "$bin/assets/fmod"
    cp "$EXAMPLE/fmod/Assets/Jump.wav" "$bin/assets/fmod/Jump.wav"
  fi
  export HAXEFMOD_TEST_STATE="$state"
  if [ "$wav" = "true" ]; then
    export FMOD_WAVWRITER="$TMP/state-$state.wav"
  else
    unset FMOD_WAVWRITER
  fi
  (
    cd "$bin"
    export DISPLAY=:99
    export LD_LIBRARY_PATH="$(pwd):${LD_LIBRARY_PATH:-}"
    EXE=$(find_exe)
    echo "Running state $state via $EXE"
    "$EXE" > "$log" 2>&1 &
    GAME_PID=$!
    for i in $(seq "$tmo"); do
      kill -0 $GAME_PID 2>/dev/null || break
      sleep 1
    done
    kill $GAME_PID 2>/dev/null || true
    wait $GAME_PID 2>/dev/null || true
  )
  unset HAXEFMOD_TEST_STATE FMOD_WAVWRITER
  grep "$gate:" "$log" || true
  grep -q "$gate: COMPLETE" "$log" || { echo "$gate never reached COMPLETE"; cat "$log"; return 1; }
  if [ -n "$extra" ]; then
    grep -q "$extra" "$log" || { echo "missing required line: $extra"; cat "$log"; return 1; }
  fi
  if grep -q "pass=false" "$log"; then echo "$gate reported failing checks"; return 1; fi
  echo "$gate passed"
}

# The static server is exec'd so the recorded pid is python's own and the
# kill reaches it. A server that outlives its step keeps the port and
# serves a directory the next build has already replaced.
# One html5 state in chromium, log gated like the workflow's browser steps.
# Every launch gets its own profile directory: a launch that reuses the
# profile of a browser still shutting down hands its URL to that instance
# and exits, and the page never runs.
# run_browser_state <state> <gate> <port> <log> [timeout] [extra-gate] [record-wav] [record-seconds]
run_browser_state() {
  local state="$1" gate="$2" port="$3" log="$4" tmo="${5:-45}" extra="${6:-}" wav="${7:-}" secs="${8:-60}"
  local raw="$log.raw" http chrome rec=""
  (cd "$WEB_BIN" && exec python3 -m http.server "$port" > /dev/null 2>&1) &
  http=$!
  sleep 1
  if [ -n "$wav" ]; then
    ffmpeg -loglevel error -f pulse -i virtual_speaker.monitor -t "$secs" -y "$wav" &
    rec=$!
  fi
  "$CHROMIUM" --no-sandbox $CHROME_GL --autoplay-policy=no-user-gesture-required \
    --no-first-run --no-default-browser-check --disable-sync --user-data-dir="$(mktemp -d "$OUT/chrome.XXXXXX")" \
    --enable-logging=stderr --v=0 --window-size=640,480 --window-position=0,0 \
    "http://localhost:$port/index.html?test=$state" > "$raw" 2>&1 &
  chrome=$!
  sleep 3
  xdotool mousemove 320 240 click 1
  for i in $(seq "$tmo"); do
    grep -q "$gate: COMPLETE" "$raw" && break
    sleep 1
  done
  [ -n "$rec" ] && wait $rec
  kill $chrome $http 2>/dev/null || true
  wait $chrome $http 2>/dev/null || true
  grep -o "$gate:.*" "$raw" | sed 's/",.*$//' | tee "$log"
  grep -q "$gate: COMPLETE" "$log" || { echo "$gate never reached COMPLETE"; return 1; }
  if [ -n "$extra" ]; then
    grep -q "$extra" "$log" || { echo "missing required line: $extra"; return 1; }
  fi
  if grep -q "pass=false" "$log"; then echo "FAIL: $gate reported failing checks"; return 1; fi
  echo "$gate passed"
}

# Serves the html5 build and records the browser's audio for the main game
# record_browser_game <port> <wav> <seconds> [console-log]
record_browser_game() {
  local port="$1" wav="$2" secs="$3" console="${4:-/dev/null}" http chrome rec
  (cd "$WEB_BIN" && exec python3 -m http.server "$port" > /dev/null 2>&1) &
  http=$!
  sleep 1
  "$CHROMIUM" --no-sandbox $CHROME_GL --autoplay-policy=no-user-gesture-required \
    --no-first-run --no-default-browser-check --disable-sync --user-data-dir="$(mktemp -d "$OUT/chrome.XXXXXX")" \
    --enable-logging=stderr --v=0 --window-size=640,480 --window-position=0,0 \
    "http://localhost:$port" > "$console" 2>&1 &
  chrome=$!
  sleep 3
  xdotool mousemove 320 240 click 1
  sleep 1
  ffmpeg -loglevel error -f pulse -i virtual_speaker.monitor -t "$secs" -y "$wav" &
  rec=$!
  sleep $((secs + 1))
  kill $chrome $http 2>/dev/null || true
  wait $rec 2>/dev/null || true
  wait $chrome $http 2>/dev/null || true
  ls -la "$wav"
}

record_volume_html5() {
  record_browser_game 8081 "$TMP/volume-test-html5.wav" 25 "$TMP/volume-test-html5-console.log"
  grep -o "VOLUME_TEST.*" "$TMP/volume-test-html5-console.log" | sed 's/",.*$//' || true
}

no_execstack() {
  local bin="$1" found=0
  for lib in "$bin"/libfmod*.so*; do
    [ -L "$lib" ] && continue
    found=1
    LINE=$(readelf -lW "$lib" | grep GNU_STACK) || { echo "FAIL: $lib has no GNU_STACK header"; return 1; }
    FLAGS=$(echo "$LINE" | awk '{print $7}')
    echo "$lib: GNU_STACK $FLAGS"
    case "$FLAGS" in *E*) echo "FAIL: $lib still has an executable stack"; return 1;; esac
  done
  [ "$found" = "1" ] || { echo "FAIL: no FMOD libraries found in $bin"; return 1; }
  echo "All FMOD libraries are loadable on modern kernels"
}

cpp_bin_dir() {
  local d="$EXAMPLE/export/linux64/bin"
  [ -d "$d" ] || d="$EXAMPLE/export/linux/bin"
  echo "$d"
}

# ---------------------------------------------------------------- unit-tests

job_unit_tests() {
  begin_job unit-tests
  step "Run unit tests" haxe tests/build.hxml
  step "Constants generator parity (CLI vs FMOD Studio script)" bash -eo pipefail -c '
    haxe -cp . --run haxefmod.tools.Generate --strings tests/fixtures/Master.strings.bank --out "$1/gen-cli"
    node tests/js/constants-parity.js "$1/gen-cli"
    haxe -cp "$1/gen-cli" --no-output FmodEvents FmodBuses FmodVCAs FmodSnapshots FmodParameters FmodEventEnum' _ "$TMP"
  step "Todo scanner end to end" bash -eo pipefail -c '
    haxe -cp . --run haxefmod.tools.Todos example-project > "$1/todos.out"
    cat "$1/todos.out"
    grep -q "PlayState.hx:.*ambient wind loop behind the music" "$1/todos.out"
    grep -q "1 sound TODO(s) remaining." "$1/todos.out"
    haxe -cp . --no-output -js "$1/todo-typing.js" -D haxefmod_todo_beep --debug haxefmod.FmodManager' _ "$TMP"
  step "Verify native shims match the FFI manifest" haxe -cp . --run haxefmod.tools.NativeManifestCheck
  for t in handles cbqueue guid instctx pcmring; do
    step "Test native $t (C99 and C++ modes)" bash -eo pipefail -c '
      gcc -std=c99 -pthread -Wall -Wextra -Werror -o "$2/test_$1_c" tests/native/test_faxe_$1.c && "$2/test_$1_c"
      g++ -x c++ -pthread -Wall -Wextra -Werror -o "$2/test_$1_cpp" tests/native/test_faxe_$1.c && "$2/test_$1_cpp"' _ "$t" "$TMP"
  done
  step "Negative-test the synth frequency gate" python3 ci/synth-gate-selftest.py
  step "Check workflow gating invariants" python3 ci/workflow-invariants.py
  step "Check FMOD version literal lockstep" python3 ci/version-lockstep.py
  step "Check hxcpp depend lockstep" python3 ci/depend-lockstep.py
  # The parity checks read the FMOD headers
  require_sdk
  step "Check the DSP parameter enums match fmod_dsp_effects.h" python3 ci/gen-dsp-parameters.py --check
  step "Compile the README examples" python3 ci/check-readme-snippets.py
  step "Check the HTML5 compile gate" python3 ci/check-html5-gate.py
  step "Check the HTML5 phrase matches the gate" python3 ci/check-html5-phrase.py
  step "Check the deprecated aliases still compile and warn" python3 ci/check-deprecations.py
  step "Check Haxe type declarations against the FMOD headers" python3 ci/check-type-parity.py
  step "Check binding coverage against the manifest" python3 ci/binding-coverage.py
  step "Test define-driven settings (haxefmod_* and -debug)" bash -eo pipefail -c '
    haxe tests/build-defines.hxml && haxe tests/build-debug-defaults.hxml'
  step "Run native tests under AddressSanitizer and UBSan" bash -eo pipefail -c '
    for t in handles cbqueue guid pcmring; do
      gcc -std=c99 -pthread -fsanitize=address,undefined -fno-sanitize-recover=all \
        -Wall -Wextra -Werror -o "$1/asan_$t" tests/native/test_faxe_$t.c
      "$1/asan_$t"
    done' _ "$TMP"
  step "Run threaded native tests under ThreadSanitizer" bash -eo pipefail -c '
    for t in cbqueue pcmring; do
      gcc -std=c99 -pthread -fsanitize=thread -Wall -Wextra -Werror -o "$1/tsan_$t" tests/native/test_faxe_$t.c
      "$1/tsan_$t"
    done' _ "$TMP"
}

# ---------------------------------------------------------------- linux-cpp

job_linux_cpp() {
  begin_job linux-cpp
  require_sdk
  rm -rf "$EXAMPLE"/export/linux*
  step "Build C++ target" bash -eo pipefail -c 'cd "$1" && haxelib run lime build linux -64' _ "$EXAMPLE"
  step "Verify FMOD libraries have no executable stack" no_execstack "$(cpp_bin_dir)"
  step "Validate build output" ./ci/validate-build.sh "$(cpp_bin_dir)" cpp
  start_display_audio
  step "Record audio" bash -eo pipefail -c '
    ffmpeg -loglevel error -f pulse -i virtual_speaker.monitor -t 30 -y "$2/audio-linux-cpp.wav" &
    REC=$!
    cd "$1" && chmod +x run.sh && timeout 30 ./run.sh > "$2/game-linux-cpp.log" 2>&1 || true
    wait $REC || true
    ls -la "$2/audio-linux-cpp.wav"' _ "$(cpp_bin_dir)" "$TMP"
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-linux-cpp.wav" 10
  step "Validate game log" ./ci/validate-game-log.sh "$TMP/game-linux-cpp.log"
  step "Build volume test" bash -eo pipefail -c 'cd "$1" && haxelib run lime clean linux && haxelib run lime build linux -64 -Daudio_test' _ "$EXAMPLE"
  step "Record volume test" bash -eo pipefail -c '
    export FMOD_WAVWRITER="$2/volume-test-linux-cpp.wav"
    cd "$1" && chmod +x run.sh
    ./run.sh > "$2/volume-test-linux-cpp.log" 2>&1 &
    PID=$!
    for i in $(seq 60); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true' _ "$(cpp_bin_dir)" "$TMP"
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-linux-cpp.wav" 15
  local bin="$EXAMPLE/export/linux*/bin"
  step "Run api-probe state" run_native_state api-probe API_PROBE "$bin" "$TMP/api-probe-linux-cpp.log" 60
  step "Run synth-test state" run_native_state synth-test SYNTH_TEST "$bin" "$TMP/synth-test-linux-cpp.log" 60 "" false true
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/state-synth-test.wav"
  step "Run cb-test state" run_native_state cb-test CB_TEST "$bin" "$TMP/cb-test-linux-cpp.log" 30 "CB_TEST: Stopped"
  step "Run ps-test state" run_native_state ps-test PS_TEST "$bin" "$TMP/ps-test-linux-cpp.log" 60 "" true
  step "Run bank-test state" run_native_state bank-test BANK_TEST "$bin" "$TMP/bank-test-linux-cpp.log" 60
  step "Run pan-test state" run_native_state pan-test PAN_TEST "$bin" "$TMP/pan-test-linux-cpp.log" 60
  step "Build manual-update variant" bash -eo pipefail -c 'cd "$1" && haxelib run lime build linux -64 -Daudio_test -Daudio_test_manual_update -Dhaxefmod_num_channels=100' _ "$EXAMPLE"
  step "Run api-probe state (manual update variant)" run_native_state api-probe API_PROBE "$bin" "$TMP/api-probe-linux-cpp-manual.log" 60
}

# ---------------------------------------------------------------- linux-hl

job_linux_hl() {
  begin_job linux-hl
  require_sdk
  local bin="$EXAMPLE/export/hl/bin"
  # A clean checkout has no custom hdll, and the first build must pick the
  # pre-built one
  rm -rf "$EXAMPLE/export/hl" "$EXAMPLE/.haxefmod"
  step "Verify environment" bash -eo pipefail -c 'cd "$1" && haxelib run haxefmod check || true' _ "$EXAMPLE"
  step "Build HashLink target (pre-built hdll)" bash -eo pipefail -c '
    cd "$1" && haxelib run lime build hl 2>&1 | tee "$2/build-prebuilt.log"
    grep -q "(pre-built)" "$2/build-prebuilt.log"' _ "$EXAMPLE" "$TMP"
  step "Build custom hdll via build-hdll" bash -eo pipefail -c '
    cd "$1" && haxelib run haxefmod build-hdll && ls -la .haxefmod/ && cat .haxefmod/hlaxe_fmod.version' _ "$EXAMPLE"
  step "Rebuild HashLink target (custom hdll)" bash -eo pipefail -c '
    rm -rf "$1/export/hl"
    cd "$1" && haxelib run lime build hl 2>&1 | tee "$2/build-custom.log"
    grep -q "(custom-compiled from .haxefmod/)" "$2/build-custom.log"' _ "$EXAMPLE" "$TMP"
  step "Verify FMOD libraries have no executable stack" no_execstack "$bin"
  step "Validate build output" ./ci/validate-build.sh "$bin" hl
  step "Stage FMOD runtime into a plain directory" bash -eo pipefail -c '
    cd "$1"
    STAGE_DIR="$2/stage-hl"
    haxelib run haxefmod stage linux hl "$STAGE_DIR" 2>&1 | tee "$2/stage-hl.log"
    grep -q "custom-compiled from .haxefmod/" "$2/stage-hl.log"
    for f in libfmod.so libfmodstudio.so hlaxe_fmod.hdll; do
      test -e "$STAGE_DIR/$f" || { echo "FAIL: $f not staged"; exit 1; }
    done
    cmp "$STAGE_DIR/hlaxe_fmod.hdll" .haxefmod/hlaxe_fmod.hdll
    if readelf -lW "$STAGE_DIR/libfmod.so" | grep GNU_STACK | grep -q RWE; then
      echo "FAIL: staged libfmod.so still has an executable stack"; exit 1
    fi
    test ! -e "$STAGE_DIR/run.sh"' _ "$EXAMPLE" "$TMP"
  start_display_audio
  step "Record audio" bash -eo pipefail -c '
    ffmpeg -loglevel error -f pulse -i virtual_speaker.monitor -t 30 -y "$2/audio-linux-hl.wav" &
    REC=$!
    cd "$1"
    export LD_LIBRARY_PATH="$(pwd):${LD_LIBRARY_PATH:-}"
    EXE=$(find . -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "run.sh" -print -quit)
    timeout 30 "$EXE" > "$2/game-linux-hl.log" 2>&1 || true
    wait $REC || true
    ls -la "$2/audio-linux-hl.wav"' _ "$bin" "$TMP"
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-linux-hl.wav" 10
  step "Validate game log" ./ci/validate-game-log.sh "$TMP/game-linux-hl.log"
  step "Build volume test" bash -eo pipefail -c 'cd "$1" && haxelib run lime clean hl && haxelib run lime build hl -Daudio_test' _ "$EXAMPLE"
  step "Record volume test" bash -eo pipefail -c '
    export FMOD_WAVWRITER="$2/volume-test-linux-hl.wav"
    cd "$1"
    export LD_LIBRARY_PATH="$(pwd):${LD_LIBRARY_PATH:-}"
    EXE=$(find . -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "run.sh" -print -quit)
    "$EXE" > "$2/volume-test-linux-hl.log" 2>&1 &
    PID=$!
    for i in $(seq 60); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true' _ "$bin" "$TMP"
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-linux-hl.wav" 15
  step "Run api-probe state" run_native_state api-probe API_PROBE "$bin" "$TMP/api-probe-linux-hl.log" 60
  step "Run synth-test state" run_native_state synth-test SYNTH_TEST "$bin" "$TMP/synth-test-linux-hl.log" 60 "" false true
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/state-synth-test.wav"
  step "Run cb-test state" run_native_state cb-test CB_TEST "$bin" "$TMP/cb-test-linux-hl.log" 30 "CB_TEST: Stopped"
  step "Run ps-test state" run_native_state ps-test PS_TEST "$bin" "$TMP/ps-test-linux-hl.log" 60 "" true
  step "Run bank-test state" run_native_state bank-test BANK_TEST "$bin" "$TMP/bank-test-linux-hl.log" 60
  step "Run pan-test state" run_native_state pan-test PAN_TEST "$bin" "$TMP/pan-test-linux-hl.log" 60
  step "Run stress-test state (smoke)" bash -eo pipefail -c '
    export HAXEFMOD_TEST_STATE=stress-test STRESS_SECONDS=15
    cd "$1"
    export LD_LIBRARY_PATH="$(pwd):${LD_LIBRARY_PATH:-}"
    EXE=$(find . -maxdepth 1 -type f -executable ! -name "*.so*" ! -name "*.hdll" ! -name "*.sh" ! -name "*.dat" -print -quit)
    "$EXE" > "$2/stress-smoke-linux-hl.log" 2>&1 &
    PID=$!
    for i in $(seq 90); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true
    grep "STRESS_TEST:" "$2/stress-smoke-linux-hl.log" || true
    grep -q "STRESS_TEST: COMPLETE" "$2/stress-smoke-linux-hl.log" || { cat "$2/stress-smoke-linux-hl.log"; exit 1; }
    ! grep -q "pass=false" "$2/stress-smoke-linux-hl.log"' _ "$bin" "$TMP"
  step "lime test end to end" bash -eo pipefail -c '
    cd "$1"
    export HAXEFMOD_TEST_STATE=api-probe
    timeout 180 haxelib run lime test hl -Daudio_test 2>&1 | tee "$2/lime-test-linux-hl.log" || true
    grep -q "API_PROBE: COMPLETE" "$2/lime-test-linux-hl.log"
    ! grep -q "pass=false" "$2/lime-test-linux-hl.log"' _ "$EXAMPLE" "$TMP"
}

# ---------------------------------------------------------------- linux-html5-chromium

job_linux_html5_chromium() {
  begin_job linux-html5-chromium
  require_sdk
  [ -n "$CHROMIUM" ] || { echo "no chromium binary found (set CHROMIUM)"; return; }
  rm -rf "$EXAMPLE/export/html5"
  step "Build HTML5 target" bash -eo pipefail -c 'cd "$1" && haxelib run lime build html5' _ "$EXAMPLE"
  step "Validate FMOD files replaced placeholders" bash -eo pipefail -c '
    FMOD_JS="$1/export/html5/bin/lib/fmodstudio.js"
    [ -f "$FMOD_JS" ] || { echo "FAIL: $FMOD_JS not found"; exit 1; }
    SIZE=$(stat --format=%s "$FMOD_JS")
    [ "$SIZE" -ge 1000 ] || { echo "FAIL: $FMOD_JS is only $SIZE bytes - still a placeholder"; exit 1; }
    echo "OK: fmodstudio.js is $SIZE bytes (real SDK file)"' _ "$EXAMPLE"
  step "Stage FMOD web files into a plain directory" bash -eo pipefail -c '
    cd "$1"
    STAGE_DIR="$2/stage-web"
    haxelib run haxefmod stage html5 html5 "$STAGE_DIR"
    for f in fmodstudio.js fmodstudio.wasm jaxe.js; do
      test -s "$STAGE_DIR/$f" || { echo "FAIL: $f not staged"; exit 1; }
    done
    cmp "$STAGE_DIR/fmodstudio.js" export/html5/bin/lib/fmodstudio.js' _ "$EXAMPLE" "$TMP"
  start_display_audio
  step "Record audio" record_browser_game 8080 "$TMP/audio-html5.wav" 30
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-html5.wav" 10
  step "Build volume test" bash -eo pipefail -c 'cd "$1" && haxelib run lime clean html5 && haxelib run lime build html5 -Daudio_test' _ "$EXAMPLE"
  step "Record volume test" record_volume_html5
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-html5.wav" 15
  step "Run API probe (JS binding coverage)" run_browser_state api-probe API_PROBE 8082 "$TMP/api-probe-html5.log" 45
  step "Run synth test (generated PCM reaches the output)" run_browser_state synth-test SYNTH_TEST 8086 "$TMP/synth-test-html5.log" 70 "" "$TMP/synth-test-html5.wav" 60
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/synth-test-html5.wav"
  step "Run callback test (JS payload delivery)" run_browser_state cb-test CB_TEST 8083 "$TMP/cb-test-html5.log" 45 "CB_TEST: Stopped"
  step "Run ps-test state (browser)" run_browser_state ps-test PS_TEST 8084 "$TMP/ps-test-html5.log" 45
  step "Run bank-test state (browser)" run_browser_state bank-test BANK_TEST 8085 "$TMP/bank-test-html5.log" 45
  step "Run pan-test state (browser)" run_browser_state pan-test PAN_TEST 8087 "$TMP/pan-test-html5.log" 45
  step "Typecheck the flixel no-sound-system variant" haxe -cp . -lib flixel -lib openfl -lib lime \
    -D FLX_NO_SOUND_SYSTEM -D FLX_STANDARD_ASSETS_DIRECTORY -D openfl-html5 --no-output -js /dev/null haxefmod.flixel.FmodFlxSetup
  step "Verify mismatched web SDK fails the build" bash -eo pipefail -c '
    DOCTORED="$2/doctored-web-sdk"
    rm -rf "$DOCTORED"
    cp -r "$FMOD_SDK_WEB" "$DOCTORED"
    sed -i "s/#define FMOD_VERSION    0x[0-9a-fA-F]*/#define FMOD_VERSION    0x00020221/" "$DOCTORED/api/core/inc/fmod_common.h"
    grep -q "0x00020221" "$DOCTORED/api/core/inc/fmod_common.h"
    cd "$1"
    haxelib run lime clean html5
    if FMOD_SDK_WEB="$DOCTORED" haxelib run lime build html5 2>&1 | tee "$2/web-mismatch-build.log"; then
      echo "FAIL: build succeeded against a mismatched web SDK"; exit 1
    fi
    grep -q "FMOD web SDK version mismatch" "$2/web-mismatch-build.log"' _ "$EXAMPLE" "$TMP"
}

# ---------------------------------------------------------------- linux-html5-firefox

firefox_state() {
  local state="$1" gate="$2" port="$3" log="$4" tmo="$5" http rc=0
  (cd "$WEB_BIN" && exec python3 -m http.server "$port" > /dev/null 2>&1) &
  http=$!
  sleep 1
  node "$ROOT/ci/run-firefox-state.js" "http://localhost:$port/index.html?test=$state" "$gate" "$log" "$tmo" || rc=$?
  kill $http 2>/dev/null || true
  wait $http 2>/dev/null || true
  return $rc
}

job_linux_html5_firefox() {
  begin_job linux-html5-firefox
  require_sdk
  rm -rf "$EXAMPLE/export/html5"
  step "Build HTML5 target" bash -eo pipefail -c 'cd "$1" && haxelib run lime build html5 -Daudio_test' _ "$EXAMPLE"
  start_display_audio
  step "Run api-probe state (firefox)" firefox_state api-probe API_PROBE 8091 "$TMP/api-probe-firefox.log" 150
  step "Run cb-test state (firefox)" firefox_state cb-test CB_TEST 8092 "$TMP/cb-test-firefox.log" 150
  step "Run ps-test state (firefox)" firefox_state ps-test PS_TEST 8093 "$TMP/ps-test-firefox.log" 120
  step "Run bank-test state (firefox)" firefox_state bank-test BANK_TEST 8094 "$TMP/bank-test-firefox.log" 120
  step "Run pan-test state (firefox)" firefox_state pan-test PAN_TEST 8095 "$TMP/pan-test-firefox.log" 180
}

# ---------------------------------------------------------------- heaps-hl

# The Heaps example on the HashLink VM: hxml build, the stage command for
# the runtime files, then the same scenarios as linux-hl
job_heaps_hl() {
  begin_job heaps-hl
  require_sdk
  local bin="$HEAPS/build/hl"
  rm -rf "$HEAPS/build" "$HEAPS/.haxefmod"
  step "Build custom hdll via build-hdll" bash -eo pipefail -c 'cd "$1" && haxelib run haxefmod build-hdll' _ "$HEAPS"
  step "Build HashLink target" bash -eo pipefail -c '
    cd "$1" && ./build.sh hl 2>&1 | tee "$2/build-hl.log"
    grep -q "(custom-compiled from .haxefmod/)" "$2/build-hl.log"' _ "$HEAPS" "$TMP"
  step "Verify FMOD libraries have no executable stack" no_execstack "$bin"
  step "Validate build output" bash -eo pipefail -c '
    for f in game.hl run.sh hlaxe_fmod.hdll libfmod.so libfmodstudio.so assets/fmod/Desktop/Master.bank; do
      test -e "$1/$f" || { echo "FAIL: missing $f"; exit 1; }
    done
    echo "OK: HashLink build directory is complete"' _ "$bin"
  start_display_audio
  step "Record audio" bash -eo pipefail -c '
    ffmpeg -loglevel error -f pulse -i virtual_speaker.monitor -t 30 -y "$2/audio-heaps-hl.wav" &
    REC=$!
    cd "$1" && timeout 30 ./run.sh > "$2/game-heaps-hl.log" 2>&1 || true
    wait $REC || true
    ls -la "$2/audio-heaps-hl.wav"' _ "$bin" "$TMP"
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-heaps-hl.wav" 10
  step "Validate game log" ./ci/validate-game-log.sh "$TMP/game-heaps-hl.log"
  step "Build test variant" bash -eo pipefail -c 'cd "$1" && ./build.sh hl -D audio_test' _ "$HEAPS"
  step "Record volume test" bash -eo pipefail -c '
    export FMOD_WAVWRITER="$2/volume-test-heaps-hl.wav"
    cd "$1"
    ./run.sh > "$2/volume-test-heaps-hl.log" 2>&1 &
    PID=$!
    for i in $(seq 60); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true' _ "$bin" "$TMP"
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-heaps-hl.wav" 15
  step "Run api-probe state" run_native_state api-probe API_PROBE "$bin" "$TMP/api-probe-heaps-hl.log" 60
  step "Run synth-test state" run_native_state synth-test SYNTH_TEST "$bin" "$TMP/synth-test-heaps-hl.log" 60 "" false true
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/state-synth-test.wav"
  step "Run cb-test state" run_native_state cb-test CB_TEST "$bin" "$TMP/cb-test-heaps-hl.log" 30 "CB_TEST: Stopped"
  step "Run ps-test state" run_native_state ps-test PS_TEST "$bin" "$TMP/ps-test-heaps-hl.log" 60 "" true
  step "Run bank-test state" run_native_state bank-test BANK_TEST "$bin" "$TMP/bank-test-heaps-hl.log" 60
  step "Run pan-test state" run_native_state pan-test PAN_TEST "$bin" "$TMP/pan-test-heaps-hl.log" 60
  step "Run stress-test state (smoke)" bash -eo pipefail -c '
    export HAXEFMOD_TEST_STATE=stress-test STRESS_SECONDS=15
    cd "$1"
    ./run.sh > "$2/stress-smoke-heaps-hl.log" 2>&1 &
    PID=$!
    for i in $(seq 90); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true
    grep "STRESS_TEST:" "$2/stress-smoke-heaps-hl.log" || true
    grep -q "STRESS_TEST: COMPLETE" "$2/stress-smoke-heaps-hl.log" || { cat "$2/stress-smoke-heaps-hl.log"; exit 1; }
    ! grep -q "pass=false" "$2/stress-smoke-heaps-hl.log"' _ "$bin" "$TMP"
}

# ---------------------------------------------------------------- heaps-js

job_heaps_js() {
  begin_job heaps-js
  require_sdk
  [ -n "$CHROMIUM" ] || { echo "no chromium binary found (set CHROMIUM)"; return; }
  rm -rf "$HEAPS/build/html5"
  WEB_BIN="$HEAPS/build/html5"
  CHROME_GL="--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader"
  step "Build HTML5 target" bash -eo pipefail -c 'cd "$1" && ./build.sh js' _ "$HEAPS"
  step "Validate build output" bash -eo pipefail -c '
    for f in index.html game.js lib/fmodstudio.js lib/fmodstudio.wasm lib/jaxe.js assets/fmod/Desktop/Master.bank; do
      test -s "$1/$f" || { echo "FAIL: missing $f"; exit 1; }
    done
    echo "OK: html5 build directory is complete"' _ "$WEB_BIN"
  start_display_audio
  step "Record audio" record_browser_game 8180 "$TMP/audio-heaps-js.wav" 30
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-heaps-js.wav" 10
  step "Build test variant" bash -eo pipefail -c 'cd "$1" && ./build.sh js -D audio_test' _ "$HEAPS"
  step "Record volume test" record_volume_heaps_js
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-heaps-js.wav" 15
  step "Run API probe (JS binding coverage)" run_browser_state api-probe API_PROBE 8182 "$TMP/api-probe-heaps-js.log" 45
  step "Run synth test (generated PCM reaches the output)" run_browser_state synth-test SYNTH_TEST 8186 "$TMP/synth-test-heaps-js.log" 70 "" "$TMP/synth-test-heaps-js.wav" 60
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/synth-test-heaps-js.wav"
  step "Run callback test (JS payload delivery)" run_browser_state cb-test CB_TEST 8183 "$TMP/cb-test-heaps-js.log" 45 "CB_TEST: Stopped"
  step "Run ps-test state (browser)" run_browser_state ps-test PS_TEST 8184 "$TMP/ps-test-heaps-js.log" 45
  step "Run bank-test state (browser)" run_browser_state bank-test BANK_TEST 8185 "$TMP/bank-test-heaps-js.log" 45
  step "Run pan-test state (browser)" run_browser_state pan-test PAN_TEST 8187 "$TMP/pan-test-heaps-js.log" 45
  WEB_BIN="$EXAMPLE/export/html5/bin"
  CHROME_GL="--disable-gpu"
}

record_volume_heaps_js() {
  record_browser_game 8181 "$TMP/volume-test-heaps-js.wav" 25 "$TMP/volume-test-heaps-js-console.log"
  grep -o "VOLUME_TEST.*" "$TMP/volume-test-heaps-js-console.log" | sed 's/",.*$//' || true
}

# ---------------------------------------------------------------- kha-linux, kha-hl

# The Kha example on a native target: khamake build with the binding
# compiled in through kfile.js, the stage command for the runtime files,
# then the same scenarios as linux-cpp
job_kha_native() {
  local target="$1" job="$2"
  begin_job "$job"
  require_sdk
  [ -d "$KHA/Tools/khamake" ] || { echo "no Kha checkout at $KHA (set KHA)"; return; }
  local bin="$KHAP/build/$target"
  step "Build $target target" bash -eo pipefail -c 'cd "$1" && ./build.sh "$2" 2>&1 | tail -5' _ "$KHAP" "$target"
  step "Verify FMOD libraries have no executable stack" no_execstack "$bin"
  step "Validate build output" bash -eo pipefail -c '
    for f in KhaPlatformer run.sh libfmod.so libfmodstudio.so assets/fmod/Desktop/Master.bank; do
      test -e "$1/$f" || { echo "FAIL: missing $f"; exit 1; }
    done
    test ! -e "$1/hlaxe_fmod.hdll"
    echo "OK: native build directory is complete"' _ "$bin"
  start_display_audio
  step "Record audio" bash -eo pipefail -c '
    ffmpeg -loglevel error -f pulse -i virtual_speaker.monitor -t 30 -y "$2/audio-$3.wav" &
    REC=$!
    cd "$1" && timeout 30 ./run.sh > "$2/game-$3.log" 2>&1 || true
    wait $REC || true
    ls -la "$2/audio-$3.wav"' _ "$bin" "$TMP" "$job"
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-$job.wav" 10
  step "Validate game log" ./ci/validate-game-log.sh "$TMP/game-$job.log"
  step "Build test variant" bash -eo pipefail -c 'cd "$1" && KHA_AUDIO_TEST=1 ./build.sh "$2" 2>&1 | tail -3' _ "$KHAP" "$target"
  step "Record volume test" bash -eo pipefail -c '
    export FMOD_WAVWRITER="$2/volume-test-$3.wav"
    cd "$1"
    ./run.sh > "$2/volume-test-$3.log" 2>&1 &
    PID=$!
    for i in $(seq 60); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true' _ "$bin" "$TMP" "$job"
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-$job.wav" 15
  step "Run api-probe state" run_native_state api-probe API_PROBE "$bin" "$TMP/api-probe-$job.log" 60
  step "Run synth-test state" run_native_state synth-test SYNTH_TEST "$bin" "$TMP/synth-test-$job.log" 60 "" false true
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/state-synth-test.wav"
  step "Run cb-test state" run_native_state cb-test CB_TEST "$bin" "$TMP/cb-test-$job.log" 30 "CB_TEST: Stopped"
  step "Run ps-test state" run_native_state ps-test PS_TEST "$bin" "$TMP/ps-test-$job.log" 60 "" true
  step "Run bank-test state" run_native_state bank-test BANK_TEST "$bin" "$TMP/bank-test-$job.log" 60
  step "Run pan-test state" run_native_state pan-test PAN_TEST "$bin" "$TMP/pan-test-$job.log" 60
  step "Run stress-test state (smoke)" bash -eo pipefail -c '
    export HAXEFMOD_TEST_STATE=stress-test STRESS_SECONDS=15
    cd "$1"
    ./run.sh > "$2/stress-smoke-$3.log" 2>&1 &
    PID=$!
    for i in $(seq 90); do kill -0 $PID 2>/dev/null || break; sleep 1; done
    kill $PID 2>/dev/null || true; wait $PID 2>/dev/null || true
    grep "STRESS_TEST:" "$2/stress-smoke-$3.log" || true
    grep -q "STRESS_TEST: COMPLETE" "$2/stress-smoke-$3.log" || { cat "$2/stress-smoke-$3.log"; exit 1; }
    ! grep -q "pass=false" "$2/stress-smoke-$3.log"' _ "$bin" "$TMP" "$job"
  if [ "$target" = linux ]; then
    step "Build manual-update variant" bash -eo pipefail -c 'cd "$1" && KHA_AUDIO_TEST=1 KHA_MANUAL_UPDATE=1 ./build.sh linux 2>&1 | tail -3' _ "$KHAP"
    step "Run api-probe state (manual update variant)" run_native_state api-probe API_PROBE "$bin" "$TMP/api-probe-$job-manual.log" 60
  fi
}

job_kha_linux() { job_kha_native linux kha-linux; }
job_kha_hl() { job_kha_native linux-hl kha-hl; }

# ---------------------------------------------------------------- kha-html5

job_kha_html5() {
  begin_job kha-html5
  require_sdk
  [ -n "$CHROMIUM" ] || { echo "no chromium binary found (set CHROMIUM)"; return; }
  [ -d "$KHA/Tools/khamake" ] || { echo "no Kha checkout at $KHA (set KHA)"; return; }
  WEB_BIN="$KHAP/build/html5"
  CHROME_GL="--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader"
  step "Build HTML5 target" bash -eo pipefail -c 'cd "$1" && ./build.sh html5 2>&1 | tail -3' _ "$KHAP"
  step "Validate build output" bash -eo pipefail -c '
    for f in index.html kha.js lib/fmodstudio.js lib/fmodstudio.wasm lib/jaxe.js assets/fmod/Desktop/Master.bank; do
      test -s "$1/$f" || { echo "FAIL: missing $f"; exit 1; }
    done
    echo "OK: html5 build directory is complete"' _ "$WEB_BIN"
  start_display_audio
  step "Record audio" record_browser_game 8280 "$TMP/audio-kha-html5.wav" 30
  step "Validate audio" ./ci/validate-audio.sh "$TMP/audio-kha-html5.wav" 10
  step "Build test variant" bash -eo pipefail -c 'cd "$1" && KHA_AUDIO_TEST=1 ./build.sh html5 2>&1 | tail -3' _ "$KHAP"
  step "Record volume test" record_volume_kha_html5
  step "Validate volume/mute" ./ci/validate-volume.sh "$TMP/volume-test-kha-html5.wav" 15
  step "Run API probe (JS binding coverage)" run_browser_state api-probe API_PROBE 8282 "$TMP/api-probe-kha-html5.log" 45
  step "Run synth test (generated PCM reaches the output)" run_browser_state synth-test SYNTH_TEST 8286 "$TMP/synth-test-kha-html5.log" 70 "" "$TMP/synth-test-kha-html5.wav" 60
  step "Validate synth audio" ./ci/validate-synth.sh "$TMP/synth-test-kha-html5.wav"
  step "Run callback test (JS payload delivery)" run_browser_state cb-test CB_TEST 8283 "$TMP/cb-test-kha-html5.log" 45 "CB_TEST: Stopped"
  step "Run ps-test state (browser)" run_browser_state ps-test PS_TEST 8284 "$TMP/ps-test-kha-html5.log" 45
  step "Run bank-test state (browser)" run_browser_state bank-test BANK_TEST 8285 "$TMP/bank-test-kha-html5.log" 45
  step "Run pan-test state (browser)" run_browser_state pan-test PAN_TEST 8287 "$TMP/pan-test-kha-html5.log" 45
  WEB_BIN="$EXAMPLE/export/html5/bin"
  CHROME_GL="--disable-gpu"
}

record_volume_kha_html5() {
  record_browser_game 8281 "$TMP/volume-test-kha-html5.wav" 25 "$TMP/volume-test-kha-html5-console.log"
  grep -o "VOLUME_TEST.*" "$TMP/volume-test-kha-html5-console.log" | sed 's/",.*$//' || true
}

# ---------------------------------------------------------------- main

for job in "${JOBS[@]}"; do
  case "$job" in
    unit-tests) job_unit_tests ;;
    linux-cpp) job_linux_cpp ;;
    linux-hl) job_linux_hl ;;
    linux-html5-chromium) job_linux_html5_chromium ;;
    linux-html5-firefox) job_linux_html5_firefox ;;
    heaps-hl) job_heaps_hl ;;
    heaps-js) job_heaps_js ;;
    kha-linux) job_kha_linux ;;
    kha-hl) job_kha_hl ;;
    kha-html5) job_kha_html5 ;;
    *) echo "unknown job: $job"; exit 2 ;;
  esac
done

echo ""
echo "################ summary"
echo "passed steps: $PASSED"
if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
  echo "failed steps: ${#FAILED_STEPS[@]}"
  for f in "${FAILED_STEPS[@]}"; do echo "  $f"; done
  exit 1
fi
echo "all steps passed"
