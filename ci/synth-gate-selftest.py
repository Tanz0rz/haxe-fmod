#!/usr/bin/env python3
# Negative-tests the synth frequency gate in audio-profile.py by feeding it
# synthetic WAVs. The correct segment sequence must pass, and each way the
# synth test can really break (silent, wrong tone, missing transition, pitch
# not applied, wrong order, 3D distance not applied) must fail. Run from
# anywhere:
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


def tone(freq, seconds, freq2=0, fade_to=None, gain=1.0):
    """gain is a flat level scale (used to stand in for 3D distance
    attenuation); fade_to ramps within the segment."""
    frames = int(RATE * seconds)
    if freq <= 0:
        return [0] * frames
    amp = AMPLITUDE >> 1 if freq2 > 0 else AMPLITUDE
    out = []
    for i in range(frames):
        sample = math.sin(2 * math.pi * freq * i / RATE)
        if freq2 > 0:
            sample += math.sin(2 * math.pi * freq2 * i / RATE)
        ramp = 1.0
        if fade_to is not None:
            ramp = 1.0 + (fade_to - 1.0) * (i / frames)
        out.append(int(sample * amp * gain * ramp))
    return out


def write_wav(path, segments):
    samples = []
    for seg in segments:
        samples.extend(tone(seg[0], seg[1],
                            seg[2] if len(seg) > 2 else 0,
                            seg[3] if len(seg) > 3 else None,
                            seg[4] if len(seg) > 4 else 1.0))
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
FADE = (500, 4.0, 0, 0.02)      # segment 6: the scheduled fade ramp
FADE_MISSING = (500, 4.0)       # the same tone with no fade applied
MID = [(0, 0.3), DUAL_RAW, (0, 0.3), DUAL_FILTERED, (0, 0.3)]
# Segments 7 and 8: the same create3d path near and far. 0.125 is the 1/8
# amplitude inverse rolloff gives at 8x the min distance.
D3_NEAR = (2000, 4.0)
D3_FAR = (2400, 4.0, 0, None, 0.125)
D3_FAR_FLAT = (2400, 4.0)       # the bug: the far segment never attenuated
TAIL = [(0, 0.3), D3_NEAR, (0, 0.3), D3_FAR]

CASES = [
    # (name, segments as (freq, seconds[, freq2[, fade_to[, gain]]]) with
    #  freq 0 = silence, must_pass)
    ("correct sequence",
     LEAD + MID + [FADE] + TAIL + [(0, 0.5)], True),
    ("correct with boundary slack",
     [(0, 3.0), (440, 3.5), (0, 1.5), (880, 3.5), (0, 1.5), (1320, 1.5), (0, 1.5),
      DUAL_RAW, (0, 1.5), DUAL_FILTERED, (0, 1.5), FADE, (0, 1.5), D3_NEAR,
      (0, 1.5), D3_FAR, (0, 2.0)], True),
    ("single flat tone",
     [(0, 1.0), (440, 22.0)], False),
    ("missing transition",
     [(0, 1.0), (440, 8.0), (0, 0.3), (1320, 2.0)] + MID + [FADE] + TAIL, False),
    ("pitch not applied (660Hz heard raw)",
     [(0, 1.0), (440, 4.0), (0, 0.3), (880, 4.0), (0, 0.3), (660, 4.0)] + MID
     + [FADE] + TAIL, False),
    ("wrong order",
     [(0, 1.0), (880, 4.0), (0, 0.3), (440, 4.0), (0, 0.3), (1320, 2.0)] + MID
     + [FADE] + TAIL, False),
    ("wrong frequency segment",
     [(0, 1.0), (440, 4.0), (0, 0.3), (1000, 4.0), (0, 0.3), (1320, 2.0)] + MID
     + [FADE] + TAIL, False),
    ("segment too short",
     [(0, 1.0), (440, 4.0), (0, 0.3), (880, 1.0), (0, 0.3), (1320, 2.0)] + MID
     + [FADE] + TAIL, False),
    ("all silence",
     [(0, 24.0)], False),
    ("lowpass not applied (5kHz survives segment 5)",
     LEAD + [DUAL_RAW, (0, 0.3), DUAL_RAW, (0, 0.3), FADE] + TAIL, False),
    ("filtered segment fully silent (DSP muted instead of filtering)",
     LEAD + [DUAL_RAW, (0, 0.3), (0, 4.0), (0, 0.3), FADE] + TAIL, False),
    ("mix missing the low tone (only 5kHz in segment 4)",
     LEAD + [(5000, 4.0), (0, 0.3), DUAL_FILTERED, (0, 0.3), FADE] + TAIL, False),
    ("fade not applied (fade segment stays flat)",
     LEAD + MID + [FADE_MISSING] + TAIL, False),
    ("fade recovers mid-ramp (volume automation misfired)",
     LEAD + MID + [(500, 2.0, 0, 0.05), (500, 2.0)] + TAIL, False),
    ("fade cut instantly (silence instead of a ramp)",
     LEAD + MID + [(500, 0.8), (0, 3.2)] + TAIL, False),
    ("3D distance not applied (far segment at the near level)",
     LEAD + MID + [FADE, (0, 0.3), D3_NEAR, (0, 0.3), D3_FAR_FLAT], False),
    ("3D segments missing entirely",
     LEAD + MID + [FADE], False),
    ("3D attributes swapped (far segment louder than near)",
     LEAD + MID + [FADE, (0, 0.3), (2000, 4.0, 0, None, 0.125), (0, 0.3),
                   (2400, 4.0)], False),
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
