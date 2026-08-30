#!/usr/bin/env python3
"""Generates the run jobs of .github/workflows/audio-test.yml.

Every native or browser build job in the workflow has a run job that
downloads the build artifact and runs one test state per matrix leg. The
run jobs are all the same shape, so this script writes them from one job
table and two templates (native, browser) into the region between the
BEGIN and END markers of the workflow file. The build jobs, and everything
else in the file, stay hand-written.

    python3 ci/generate-run-jobs.py          rewrites the region in place
    python3 ci/generate-run-jobs.py --check  fails when the region is stale

A job's legs: game-audio (the plain game, recorded), volume (the volume
and mute flow), the six log-gated states, stress-test (native only) and
api-probe-manual where a <job>-build-manual job exists.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "audio-test.yml")
BEGIN = "  # ---- BEGIN generated run jobs (ci/generate-run-jobs.py) ----\n"
END = "  # ---- END generated run jobs ----\n"

STATES = [("api-probe", "API_PROBE"), ("synth-test", "SYNTH_TEST"), ("cb-test", "CB_TEST"),
          ("ps-test", "PS_TEST"), ("bank-test", "BANK_TEST"), ("pan-test", "PAN_TEST")]


class Job:
    def __init__(self, name, title, os_, runner, download, launch, bindir=None, browser=False,
                 manual=None, hashlink=False, brew=""):
        self.name = name
        # Display name, "Engine / Platform" like the build jobs carry
        self.title = title
        self.os = os_
        self.runner = runner
        # Where the build artifact lands, and the directory the game runs in
        # (a macOS app bundle downloads as the bundle, runs in Contents/MacOS)
        self.download = download
        self.bindir = bindir or download
        self.launch = launch
        self.browser = browser
        # Directory of the manual-update variant, when a -build-manual job exists
        self.manual = manual
        # Linux Heaps legs need the HashLink VM installed
        self.hashlink = hashlink
        # Extra Homebrew packages a macOS leg runs against
        self.brew = brew

    @property
    def windows(self):
        return self.os == "windows"

    @property
    def mac(self):
        return self.os == "mac"

    @property
    def linux(self):
        return self.os == "linux"

    def tmp(self, f):
        return f"$GITHUB_WORKSPACE/{f}" if self.windows else f"/tmp/{f}"

    def tmpx(self, f):
        return f"${{{{ github.workspace }}}}/{f}" if self.windows else f"/tmp/{f}"


EZ = "example-project/EZPlatformer/export"
HEAPS = "example-project/HeapsPlatformer"
KHA = "example-project/KhaPlatformer"
MAC_APP = "EZPlatformerTestEdition.app"

JOBS = [
    # flixel
    Job("linux-cpp", "Flixel / Linux C++", "linux", "ubuntu-latest", f"{EZ}/linux/bin", "./run.sh", manual=f"{EZ}/linux/bin"),
    Job("linux-hl", "Flixel / Linux HashLink", "linux", "ubuntu-latest", f"{EZ}/hl/bin", 'env LD_LIBRARY_PATH="$(pwd)" ./EZPlatformerTestEdition'),
    Job("linux-html5-chromium", "Flixel / Chromium", "linux", "ubuntu-latest", f"{EZ}/html5/bin", "", browser=True),
    Job("mac-cpp", "Flixel / macOS C++", "mac", "macos-14", f"{EZ}/macos/bin/{MAC_APP}", "./EZPlatformerTestEdition",
        bindir=f"{EZ}/macos/bin/{MAC_APP}/Contents/MacOS"),
    Job("mac-hl", "Flixel / macOS HashLink", "mac", "macos-14", f"{EZ}/hl/bin/{MAC_APP}", "./EZPlatformerTestEdition",
        bindir=f"{EZ}/hl/bin/{MAC_APP}/Contents/MacOS"),
    Job("windows-cpp", "Flixel / Windows C++", "windows", "windows-latest", f"{EZ}/windows/bin", "./EZPlatformerTestEdition.exe"),
    Job("windows-hl", "Flixel / Windows HashLink", "windows", "windows-latest", f"{EZ}/hl/bin", "./EZPlatformerTestEdition.exe"),
    # Heaps
    Job("heaps-hl", "Heaps / Linux HashLink", "linux", "ubuntu-latest", f"{HEAPS}/build/hl", "./run.sh", manual=f"{HEAPS}/build-manual/hl", hashlink=True),
    Job("heaps-html5", "Heaps / Chromium", "linux", "ubuntu-latest", f"{HEAPS}/build/html5", "", browser=True),
    # HL/C links Homebrew's libhl and hdlls
    Job("heaps-mac-hl", "Heaps / macOS HL/C", "mac", "macos-14", f"{HEAPS}/build/hl", "./game", brew="hashlink libuv"),
    Job("heaps-windows-hl", "Heaps / Windows HashLink", "windows", "windows-latest", f"{HEAPS}/build/hl", "./HeapsPlatformer.exe"),
    # Kha
    Job("kha-linux", "Kha / Linux C++", "linux", "ubuntu-latest", f"{KHA}/build/linux", "./run.sh", manual=f"{KHA}/build-manual/linux"),
    Job("kha-hl", "Kha / Linux HL/C", "linux", "ubuntu-latest", f"{KHA}/build/linux-hl", "./run.sh"),
    Job("kha-html5", "Kha / Chromium", "linux", "ubuntu-latest", f"{KHA}/build/html5", "", browser=True),
    Job("kha-mac", "Kha / macOS C++", "mac", "macos-14", f"{KHA}/build/osx", "./KhaPlatformer"),
    Job("kha-mac-hl", "Kha / macOS HL/C", "mac", "macos-14", f"{KHA}/build/osx-hl", "./KhaPlatformer"),
    Job("kha-windows", "Kha / Windows C++", "windows", "windows-2022", f"{KHA}/build/windows", "./KhaPlatformer.exe"),
    Job("kha-windows-hl", "Kha / Windows HL/C", "windows", "windows-2022", f"{KHA}/build/windows-hl", "./KhaPlatformer.exe"),
]

# The HashLink VM for the Linux Heaps legs, from the same cached build the
# heaps-hl build job makes
LINUX_HASHLINK = """
      - name: Install system dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libpng-dev libturbojpeg0-dev libsdl2-dev libgl1-mesa-dev \\
            libopenal-dev libmbedtls-dev libuv1-dev libvorbis-dev libsqlite3-dev libz-dev

      - name: Cache the HashLink build
        id: hl-cache
        uses: actions/cache@v5
        with:
          path: /tmp/hashlink-src
          key: hashlink-781960a5-${{ runner.os }}

      - name: Build HashLink
        if: steps.hl-cache.outputs.cache-hit != 'true'
        run: |
          # Same pin as linux-hl: the commit before the SDL3 port
          git clone https://github.com/HaxeFoundation/hashlink.git /tmp/hashlink-src
          cd /tmp/hashlink-src
          git checkout 781960a5daca32ad6d5cea87b255fe8b5872551e
          make -j$(nproc)

      - name: Install HashLink
        run: |
          cd /tmp/hashlink-src
          sudo make install
          sudo ldconfig
          hl --version || echo "HashLink installed"
"""

AUDIO_SETUP = """      - name: Start display and audio
        run: |
          Xvfb :99 -screen 0 1024x768x24 &
          export DISPLAY=:99
          sleep 1
          pulseaudio --start --exit-idle-time=-1 || true
          pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=VirtualSpeaker
          pactl set-default-sink virtual_speaker
          # FMOD opens ALSA, which routes through PulseAudio
          cat > ~/.asoundrc << 'ALSA_EOF'
          pcm.!default {
            type pulse
          }
          ctl.!default {
            type pulse
          }
          ALSA_EOF
          echo "DISPLAY=:99" >> "$GITHUB_ENV"
"""

# FMOD's wavwriter leaves the channel count at zero in the header when the
# process is killed before it closes the file
WAVFIX = """      - name: Fix WAV headers
        if: ${{ !cancelled() }}
        shell: python
        run: |
          import struct, os, glob
          for wav in glob.glob(os.path.join(os.environ['GITHUB_WORKSPACE'], '*.wav')):
              with open(wav, 'r+b') as f:
                  f.seek(22)
                  if struct.unpack('<H', f.read(2))[0] == 0:
                      f.seek(22); f.write(struct.pack('<H', 2))
                      f.seek(28); f.write(struct.pack('<I', 192000)); f.write(struct.pack('<H', 4))
                      print("fixed header of " + wav)

"""


def tag_condition(text, name):
    """The job's if: line, with the same tag list every hand-written job carries."""
    m = re.search(r"\(!contains\(github\.event\.head_commit\.message, '\[linux-cpp\]'\)[^\n]*?'\[kha-windows-hl\]'\)\)", text)
    if not m:
        raise SystemExit("could not find the solo tag list in the workflow")
    return ("${{ startsWith(github.ref, 'refs/tags/') || (!contains(github.event.head_commit.message, '[skip-build]') "
            "&& (contains(github.event.head_commit.message, '[%s]') || %s)) }}" % (name, m.group(0)))


def setup_steps(j):
    if j.linux:
        pkgs = "pulseaudio libasound2-plugins xvfb ffmpeg" + (" chromium-browser xdotool" if j.browser else " libgl1-mesa-dri libegl1 libgles2")
        return f"""      - name: Install runtime dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y {pkgs}
{LINUX_HASHLINK if j.hashlink else ""}
{AUDIO_SETUP}"""
    if j.mac:
        return f"""      - name: Install runtime dependencies
        run: |
          brew untap aws/tap 2>/dev/null || true
          brew install ffmpeg {j.brew}
"""
    return """      - name: Install ffmpeg
        shell: powershell
        run: choco install ffmpeg -y --no-progress

      - name: Add ffmpeg to PATH
        run: |
          echo "C:\\\\ProgramData\\\\chocolatey\\\\bin" >> "$GITHUB_PATH"
          for d in /c/ProgramData/chocolatey/lib/ffmpeg/tools/*/bin; do
            [ -d "$d" ] && cygpath -w "$d" >> "$GITHUB_PATH"
          done
"""


def run_for(j, seconds, log, wav_env):
    """Runs the game for up to `seconds`, the log mirrored to `log`."""
    if j.linux and wav_env is None:
        # Linux records the real output through PulseAudio
        return f"""          export HAXEFMOD_LOG_FILE={log}
          ffmpeg -f pulse -i virtual_speaker.monitor -t {seconds} -y {j.tmp(f"audio-{j.name}.wav")} &
          RECORD_PID=$!
          cd {j.bindir}
          timeout {seconds} {j.launch} > {log} 2>&1 || true
          cd -
          wait $RECORD_PID || true
"""
    if j.windows:
        return f"""          export FMOD_WAVWRITER="{wav_env}"
          export HAXEFMOD_LOG_FILE="{log}"
          cd {j.bindir}
          timeout {seconds} {j.launch} > "{log}" 2>&1 || true
          cd -
"""
    return f"""          export FMOD_WAVWRITER={wav_env}
          export HAXEFMOD_LOG_FILE={log}
          cd {j.bindir}
          {j.launch} > {log} 2>&1 &
          GAME_PID=$!
          cd -
          for i in $(seq {seconds}); do
            kill -0 $GAME_PID 2>/dev/null || break
            sleep 1
          done
          kill $GAME_PID 2>/dev/null || true
          wait $GAME_PID 2>/dev/null || true
"""


def native_steps(j):
    L, X = j.tmp, j.tmpx
    game_wav = None if j.linux else L(f"audio-{j.name}.wav")
    record_game = run_for(j, 30 if j.linux else 60, L(f"game-{j.name}.log"), game_wav)
    record_volume = "          export HAXEFMOD_TEST_STATE=volume\n" + run_for(j, 60, L(f"volume-test-{j.name}.log"), L(f"volume-test-{j.name}.wav"))
    # Linux plays through PulseAudio, so only the synth state needs the
    # wavwriter there. macOS and Windows record everything through it.
    wavwriter = '"true"' if not j.linux else "\"${{ matrix.state == 'synth-test' && 'true' || 'false' }}\""
    manual = f"""
      - name: Run api-probe state (manual update variant)
        if: matrix.state == 'api-probe-manual'
        uses: ./.github/actions/run-test-state
        with:
          state: api-probe
          gate: API_PROBE
          timeout: "60"
          bin-dir: {j.manual}
          log-file: {X(f"api-probe-{j.name}-manual.log")}
          use-wavwriter: {wavwriter}
""" if j.manual else ""
    return f"""      - name: Record audio
        if: matrix.state == 'game-audio'
        run: |
{record_game}          echo "=== Game log ==="
          cat {L(f"game-{j.name}.log")} || true
          echo "=== End game log ==="

      - name: Record volume test
        if: matrix.state == 'volume'
        run: |
{record_volume}
{WAVFIX if j.windows else ""}      - name: Validate audio
        if: matrix.state == 'game-audio'
        run: ./ci/validate-audio.sh {L(f"audio-{j.name}.wav")} 10

      - name: Validate game log
        if: matrix.state == 'game-audio'
        run: ./ci/validate-game-log.sh {L(f"game-{j.name}.log")}

      - name: Validate volume/mute
        if: matrix.state == 'volume'
        run: ./ci/validate-volume.sh {L(f"volume-test-{j.name}.wav")} 15

      - name: Run state
        if: matrix.gate
        uses: ./.github/actions/run-test-state
        with:
          state: ${{{{ matrix.state }}}}
          gate: ${{{{ matrix.gate }}}}
          timeout: "60"
          bin-dir: {j.bindir}
          log-file: {X(f"${{{{ matrix.state }}}}-{j.name}.log")}
          extra-gate: "${{{{ matrix.state == 'cb-test' && 'CB_TEST: Stopped' || '' }}}}"
          copy-jump-wav: "${{{{ matrix.state == 'ps-test' && 'true' || 'false' }}}}"
          use-wavwriter: {wavwriter}

      - name: Validate synth audio
        if: matrix.state == 'synth-test'
        run: ./ci/validate-synth.sh "${{RUNNER_TEMP}}/state-synth-test.wav"
{manual}
      - name: Run stress-test state (smoke)
        if: matrix.state == 'stress-test'
        run: |
          export HAXEFMOD_TEST_STATE=stress-test
          export STRESS_SECONDS=15
          export FMOD_WAVWRITER="${{RUNNER_TEMP}}/stress-smoke.wav"
          LOG={L(f"stress-smoke-{j.name}.log")}
          export HAXEFMOD_LOG_FILE="$LOG"
          cd {j.bindir}
          {j.launch} > "$LOG" 2>&1 &
          GAME_PID=$!
          cd -
          for i in $(seq 90); do
            kill -0 $GAME_PID 2>/dev/null || break
            sleep 1
          done
          kill $GAME_PID 2>/dev/null || true
          wait $GAME_PID 2>/dev/null || true
          grep "STRESS_TEST:" "$LOG" || true
          grep -q "STRESS_TEST: COMPLETE" "$LOG" || {{ echo "Stress smoke never completed, full log:"; cat "$LOG"; exit 1; }}
          if grep -q "pass=false" "$LOG"; then echo "Stress smoke reported failing checks"; exit 1; fi
"""


CHROME = """chromium-browser \\
            --no-sandbox --no-first-run --no-default-browser-check --user-data-dir="$PROFILE" \\
            --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader \\
            --autoplay-policy=no-user-gesture-required \\
            --enable-logging=stderr --v=0 \\
            --window-size=640,480 \\
            --window-position=0,0 \\"""


def serve(bindir, port):
    return f"""          cd {bindir}
          python3 -m http.server {port} &
          HTTP_PID=$!
          cd -
          sleep 1
          PROFILE=$(mktemp -d)
"""


def browser_steps(j):
    return f"""      - name: Record audio
        if: matrix.state == 'game-audio'
        run: |
{serve(j.bindir, 8180)}          {CHROME}
            http://localhost:8180 &
          CHROME_PID=$!
          sleep 3
          xdotool mousemove 320 240 click 1
          sleep 1
          ffmpeg -f pulse -i virtual_speaker.monitor -t 30 -y /tmp/audio-{j.name}.wav &
          RECORD_PID=$!
          sleep 4
          xdotool mousemove 320 240 click 1
          sleep 27
          kill $CHROME_PID || true
          pkill -f "$PROFILE" || true
          kill $HTTP_PID || true
          wait $RECORD_PID || true

      - name: Validate audio
        if: matrix.state == 'game-audio'
        run: ./ci/validate-audio.sh /tmp/audio-{j.name}.wav 10

      - name: Record volume test
        if: matrix.state == 'volume'
        run: |
{serve(j.bindir, 8181)}          {CHROME}
            "http://localhost:8181/index.html?test=volume" > /tmp/volume-test-{j.name}-console.log 2>&1 &
          CHROME_PID=$!
          sleep 3
          xdotool mousemove 320 240 click 1
          sleep 1
          ffmpeg -f pulse -i virtual_speaker.monitor -t 25 -y /tmp/volume-test-{j.name}.wav &
          RECORD_PID=$!
          sleep 4
          xdotool mousemove 320 240 click 1
          sleep 22
          kill $CHROME_PID || true
          pkill -f "$PROFILE" || true
          kill $HTTP_PID || true
          wait $RECORD_PID || true
          grep -o "VOLUME_TEST.*" /tmp/volume-test-{j.name}-console.log | sed 's/",.*$//' || true

      - name: Validate volume/mute
        if: matrix.state == 'volume'
        run: ./ci/validate-volume.sh /tmp/volume-test-{j.name}.wav 15

      - name: Run state
        if: matrix.gate
        run: |
          STATE="${{{{ matrix.state }}}}"
          GATE="${{{{ matrix.gate }}}}"
          RAW=/tmp/$STATE-{j.name}.log.raw
          LOG=/tmp/$STATE-{j.name}.log
{serve(j.bindir, 8182)}          if [ "$STATE" = synth-test ]; then
            ffmpeg -f pulse -i virtual_speaker.monitor -t 60 -y /tmp/synth-test-{j.name}.wav &
            RECORD_PID=$!
          fi
          {CHROME}
            "http://localhost:8182/index.html?test=$STATE" > "$RAW" 2>&1 &
          CHROME_PID=$!
          sleep 3
          xdotool mousemove 320 240 click 1
          sleep 5
          xdotool mousemove 320 240 click 1
          for i in $(seq 70); do
            grep -q "$GATE: COMPLETE" "$RAW" && break
            sleep 1
          done
          [ "$STATE" = synth-test ] && wait $RECORD_PID || true
          kill $CHROME_PID || true
          pkill -f "$PROFILE" || true
          kill $HTTP_PID || true
          grep -v "dbus" "$RAW" | tail -n 15 || true
          grep -o "$GATE:.*" "$RAW" | sed 's/",.*$//' | tee "$LOG"
          grep -q "$GATE: COMPLETE" "$LOG"
          if [ "$STATE" = cb-test ]; then
            # Delivery end to end. Chromium delivers no nested timeline
            # beats, so that check is informational in the browser.
            grep -q "CB_TEST: Stopped" "$LOG"
          elif grep -q "pass=false" "$LOG"; then
            echo "FAIL: $GATE reported failing checks"
            exit 1
          fi

      - name: Validate synth audio
        if: matrix.state == 'synth-test'
        run: ./ci/validate-synth.sh /tmp/synth-test-{j.name}.wav
"""


def run_job(j, text):
    states = ["game-audio", "volume"] + [s for s, _ in STATES]
    if not j.browser:
        states.append("stress-test")
    if j.manual:
        states.append("api-probe-manual")
    include = "\n".join(f"          - state: {s}\n            gate: {g}" for s, g in STATES)
    needs = f"[{j.name}-build, {j.name}-build-manual]" if j.manual else f"{j.name}-build"
    download_if = "        if: matrix.state != 'api-probe-manual'\n" if j.manual else ""
    manual_download = f"""
      - name: Download manual-update build
        if: matrix.state == 'api-probe-manual'
        uses: actions/download-artifact@v6
        with:
          name: build-{j.name}-manual
          path: {j.manual}
""" if j.manual else ""
    chmod = ""
    if not j.windows:
        dirs = [j.bindir] + ([j.manual] if j.manual else [])
        lines = "\n".join(f"          find {d} -maxdepth 1 -type f -exec chmod +x {{}} + 2>/dev/null || true" for d in dirs)
        chmod = f"""
      - name: Restore executable bits
        run: |
          # Artifacts do not keep file modes
{lines}
"""
    defaults = "    defaults:\n      run:\n        shell: bash\n" if j.windows else ""
    steps = browser_steps(j) if j.browser else native_steps(j)
    return f"""
  {j.name}:
    name: {j.title} / ${{{{ matrix.state }}}}
    needs: {needs}
    runs-on: {j.runner}
    if: {tag_condition(text, j.name)}
    timeout-minutes: 20
    strategy:
      fail-fast: false
      matrix:
        state: [{", ".join(states)}]
        include:
{include}
{defaults}    steps:
      - uses: actions/checkout@v5

      - name: Download build
{download_if}        uses: actions/download-artifact@v6
        with:
          name: build-{j.name}
          # A single-path upload drops the directory prefix
          path: {j.download}
{manual_download}{chmod}
{setup_steps(j)}
{steps}
      - name: Upload logs
        uses: actions/upload-artifact@v6
        if: always()
        with:
          name: logs-{j.name}-${{{{ matrix.state }}}}
          path: |
            {j.tmpx(f"*-{j.name}.wav")}
            {j.tmpx(f"*-{j.name}.log")}
            {j.tmpx(f"*-{j.name}-console.log")}
          if-no-files-found: ignore
          overwrite: true
"""


def generate(text):
    return BEGIN + "".join(run_job(j, text) for j in JOBS) + "\n" + END


def main():
    text = open(WORKFLOW).read()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end < 0:
        raise SystemExit("workflow has no generated run jobs region")
    end += len(END)
    fresh = text[:start] + generate(text) + text[end:]
    if "--check" in sys.argv:
        if fresh != text:
            print("audio-test.yml run jobs are stale, run: python3 ci/generate-run-jobs.py")
            sys.exit(1)
        print("audio-test.yml run jobs match ci/generate-run-jobs.py")
        return
    open(WORKFLOW, "w").write(fresh)
    print(f"wrote {len(JOBS)} run jobs")


if __name__ == "__main__":
    main()
