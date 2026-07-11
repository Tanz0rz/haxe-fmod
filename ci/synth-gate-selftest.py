#!/usr/bin/env python3
# Negative-tests the synth frequency gate in audio-profile.py by feeding it
# synthetic WAVs. The correct segment sequence must pass, and each way the
# synth test can really break (silent, wrong tone, missing transition, pitch
# not applied, wrong order) must fail. Run from anywhere:
#   python3 ci/synth-gate-selftest.py
import math
import os
import struct
import subprocess
import sys
import tempfile

RATE = 48000
CHANNELS = 2
AMPLITUDE = 0x5000
PROFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio-profile.py")


def tone(freq, seconds, freq2=0):
    frames = int(RATE * seconds)
    if freq <= 0:
        return [0] * frames
    amp = AMPLITUDE >> 1 if freq2 > 0 else AMPLITUDE
    out = []
    for i in range(frames):
        sample = math.sin(2 * math.pi * freq * i / RATE)
        if freq2 > 0:
            sample += math.sin(2 * math.pi * freq2 * i / RATE)
        out.append(int(sample * amp))
    return out


def write_wav(path, segments):
    samples = []
    for seg in segments:
        samples.extend(tone(seg[0], seg[1], seg[2] if len(seg) > 2 else 0))
    frames = len(samples)
    data = struct.pack("<{}h".format(frames * CHANNELS),
                       *[s for s in samples for _ in range(CHANNELS)])
    with open(path, "wb") as handle:
        handle.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE")
        handle.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, CHANNELS, RATE,
                                           RATE * CHANNELS * 2, CHANNELS * 2, 16))
        handle.write(b"data" + struct.pack("<I", len(data)) + data)


def run_gate(path):
    result = subprocess.run([sys.executable, PROFILE, path, "--synth"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return result.returncode, result.stdout.decode("utf-8", "replace")


# Shared tail: the pure-tone segments every case builds on
LEAD = [(0, 1.0), (440, 4.0), (0, 0.3), (880, 4.0), (0, 0.3), (1320, 2.0), (0, 0.3)]
DUAL_RAW = (300, 4.0, 5000)     # segment 4: the mix, unfiltered
DUAL_FILTERED = (300, 4.0)      # segment 5: what the lowpass leaves audible

CASES = [
    # (name, segments as (freq, seconds[, freq2]) with freq 0 = silence, must_pass)
    ("correct sequence",
     LEAD + [DUAL_RAW, (0, 0.3), DUAL_FILTERED, (0, 0.5)], True),
    ("correct with boundary slack",
     [(0, 3.0), (440, 3.5), (0, 1.5), (880, 3.5), (0, 1.5), (1320, 1.5), (0, 1.5),
      DUAL_RAW, (0, 1.5), DUAL_FILTERED, (0, 2.0)], True),
    ("single flat tone",
     [(0, 1.0), (440, 18.0)], False),
    ("missing transition",
     [(0, 1.0), (440, 8.0), (0, 0.3), (1320, 2.0), (0, 0.3), DUAL_RAW, (0, 0.3), DUAL_FILTERED], False),
    ("pitch not applied (660Hz heard raw)",
     [(0, 1.0), (440, 4.0), (0, 0.3), (880, 4.0), (0, 0.3), (660, 4.0), (0, 0.3),
      DUAL_RAW, (0, 0.3), DUAL_FILTERED], False),
    ("wrong order",
     [(0, 1.0), (880, 4.0), (0, 0.3), (440, 4.0), (0, 0.3), (1320, 2.0), (0, 0.3),
      DUAL_RAW, (0, 0.3), DUAL_FILTERED], False),
    ("wrong frequency segment",
     [(0, 1.0), (440, 4.0), (0, 0.3), (1000, 4.0), (0, 0.3), (1320, 2.0), (0, 0.3),
      DUAL_RAW, (0, 0.3), DUAL_FILTERED], False),
    ("segment too short",
     [(0, 1.0), (440, 4.0), (0, 0.3), (880, 1.0), (0, 0.3), (1320, 2.0), (0, 0.3),
      DUAL_RAW, (0, 0.3), DUAL_FILTERED], False),
    ("all silence",
     [(0, 20.0)], False),
    ("lowpass not applied (5kHz survives the final segment)",
     LEAD + [DUAL_RAW, (0, 0.3), DUAL_RAW], False),
    ("filtered segment fully silent (DSP muted instead of filtering)",
     LEAD + [DUAL_RAW, (0, 0.3), (0, 4.0)], False),
    ("mix missing the low tone (only 5kHz in segment 4)",
     LEAD + [(5000, 4.0), (0, 0.3), DUAL_FILTERED], False),
]


def main():
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        for index, (name, segments, must_pass) in enumerate(CASES):
            path = os.path.join(tmp, "case{}.wav".format(index))
            write_wav(path, segments)
            code, output = run_gate(path)
            ok = (code == 0) == must_pass
            print("SELFTEST: {} -> exit {} (expected {}) {}".format(
                name, code, "0" if must_pass else "nonzero", "OK" if ok else "WRONG"))
            if not ok:
                failures += 1
                print(output)
    if failures:
        print("SELFTEST: FAILED ({} case(s))".format(failures))
        sys.exit(1)
    print("SELFTEST: all {} cases behaved as expected".format(len(CASES)))


if __name__ == "__main__":
    main()
