#!/usr/bin/env python3
# Deep audio profile of a recorded WAV: windowed RMS analysis that separates
# the recording envelope (leading/trailing silence from recorder slack and
# game boot time) from the actual audio, then gates on properties of the
# active region that a whole-file mean-volume check cannot see:
#
#   - enough ACTIVE audio (a 30s recording of 3s of sound must fail)
#   - no dropouts (internal silent gaps mean mixer stalls or update hangs)
#   - every channel carries signal (catches dead-channel and downmix bugs)
#   - no sustained clipping
#   - bounded leading silence (a hung boot eating the recording must fail)
#
# Usage:
#   audio-profile.py <wav> [--min-active S] [--max-gap S] [--max-lead S]
#                    [--min-channels N] [--no-gate]
#
# Handles FMOD WAVWRITER quirks: an unfinalized data chunk (size 0) is read
# to end of file, and a malformed fmt chunk (0 channels, from Sys.exit on
# Windows) falls back to the known CI format of 48kHz 16-bit stereo.
# Prints measurements and a one-char-per-second profile strip either way;
# --no-gate reports without failing (used for the volume test, whose muted
# phase is intentional silence).
import math
import struct
import sys

WINDOW_MS = 250
SILENCE_DB = -60.0
CLIP_SAMPLE = 32700
CLIP_WINDOWS = 3

# The synth-test contract (SynthTestState.hx): tone segments in this order,
# each at least this long in the recording. Windows are labeled by the SET
# of tones present. 1320Hz is 660Hz data played at pitch 2.0, so 660Hz
# appearing anywhere means the pitch was not applied. Segment 5 is the
# 300+5000 mix through a lowpass: 5000Hz appearing there means the DSP
# effect was not applied. Segments 7 and 8 are the same PcmStream.create3d
# path at two distances, and carry different tones only so the run labeling
# keeps them apart.
SYNTH_EXPECTED = [
    (frozenset([440.0]), 3.0),
    (frozenset([880.0]), 3.0),
    (frozenset([1320.0]), 1.2),
    (frozenset([300.0, 5000.0]), 3.0),
    (frozenset([300.0]), 3.0),
    (frozenset([500.0]), 3.0),
    (frozenset([2000.0]), 3.0),
    (frozenset([2400.0]), 3.0),
]
SYNTH_DATA_FREQ = 660.0
SYNTH_FILTERED_FREQ = 5000.0
SYNTH_FADE_TONES = frozenset([500.0])
SYNTH_FADE_DROP_DB = 12.0
# Positions in SYNTH_EXPECTED. Indexed rather than taken from the end of
# the run list so that appending a segment can never silently retire one of
# these checks.
SYNTH_FADE_INDEX = 5
SYNTH_3D_NEAR_INDEX = 6
SYNTH_3D_FAR_INDEX = 7
# Segment 8 sits 8x its min distance out, which inverse rolloff makes 1/8
# the amplitude (-18dB). Required drop leaves room for rolloff differences
# between platforms and FMOD versions.
SYNTH_3D_DROP_DB = 12.0
SYNTH_CANDIDATES = [300.0, 440.0, 500.0, 660.0, 880.0, 1320.0, 2000.0, 2400.0, 5000.0]
SYNTH_PRESENT_MARGIN_DB = 18.0  # present = within this of the window max
SYNTH_PRESENT_FLOOR_DB = -55.0  # and above this absolute level
SYNTH_MIN_RUN = 2  # windows (0.5s) - shorter runs are boundary noise


def parse_args(argv):
    options = {
        "min_active": 10.0,
        "max_gap": 1.0,
        "max_lead": 20.0,
        "min_channels": 2,
        "gate": True,
        "synth": False,
    }
    path = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--min-active":
            i += 1
            options["min_active"] = float(argv[i])
        elif arg == "--max-gap":
            i += 1
            options["max_gap"] = float(argv[i])
        elif arg == "--max-lead":
            i += 1
            options["max_lead"] = float(argv[i])
        elif arg == "--min-channels":
            i += 1
            options["min_channels"] = int(argv[i])
        elif arg == "--no-gate":
            options["gate"] = False
        elif arg == "--synth":
            options["synth"] = True
        elif path is None:
            path = arg
        else:
            print("unexpected argument: " + arg)
            sys.exit(2)
        i += 1
    if path is None:
        print("usage: audio-profile.py <wav> [options]")
        sys.exit(2)
    return path, options


def read_wav(path):
    with open(path, "rb") as handle:
        data = handle.read()
    channels, rate, bits = 2, 48000, 16
    pcm = None
    if data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        pos = 12
        while pos + 8 <= len(data):
            chunk_id = data[pos:pos + 4]
            size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
            if chunk_id == b"fmt " and size >= 16:
                _, fmt_channels, fmt_rate, _, _, fmt_bits = struct.unpack(
                    "<HHIIHH", data[pos + 8:pos + 24])
                # A zero channel count is the Windows WAVWRITER header bug;
                # keep the CI-format defaults in that case
                if fmt_channels > 0:
                    channels, rate, bits = fmt_channels, fmt_rate, fmt_bits
            elif chunk_id == b"data":
                # size 0 = unfinalized WAVWRITER header. data runs to EOF
                pcm = data[pos + 8:pos + 8 + size] if size > 0 else data[pos + 8:]
                if size == 0:
                    break
            pos += 8 + size + (size & 1)
    if pcm is None:
        # No parseable RIFF structure: treat the whole file as raw PCM
        pcm = data[44:] if len(data) > 44 else b""
    if bits != 16:
        print("unsupported bit depth: " + str(bits))
        sys.exit(2)
    return channels, rate, pcm


def rms_db(samples):
    if not samples:
        return -120.0
    acc = 0
    for value in samples:
        acc += value * value
    mean_square = acc / len(samples)
    if mean_square <= 0:
        return -120.0
    return 10.0 * math.log10(mean_square / (32768.0 * 32768.0))


def goertzel_db(samples, rate, freq):
    """Amplitude of one frequency in dBFS via the Goertzel algorithm."""
    count = len(samples)
    if count == 0:
        return -120.0
    coeff = 2.0 * math.cos(2.0 * math.pi * freq / rate)
    s1 = 0.0
    s2 = 0.0
    for value in samples:
        s0 = value + coeff * s1 - s2
        s2 = s1
        s1 = s0
    power = s1 * s1 + s2 * s2 - coeff * s1 * s2
    amplitude = 2.0 * math.sqrt(power if power > 0 else 0.0) / count
    if amplitude <= 0:
        return -120.0
    return 20.0 * math.log10(amplitude / 32768.0)


def synth_gate(channels, rate, pcm, window_count, window_frames, window_dbs):
    """Gates the synth-test recording: windows are labeled by the set of
    tones present and the labeled runs must reproduce SYNTH_EXPECTED."""
    block = channels * 2
    window_seconds = WINDOW_MS / 1000.0
    labels = []
    for index in range(window_count):
        if window_dbs[index] <= SILENCE_DB:
            labels.append(None)
            continue
        start = index * window_frames * block
        chunk = pcm[start:start + window_frames * block]
        interleaved = struct.unpack("<{}h".format(len(chunk) // 2), chunk)
        # Mono mix so channel layout does not matter
        mono = [sum(interleaved[i * channels:(i + 1) * channels]) / channels
                for i in range(len(interleaved) // channels)]
        levels = {}
        for freq in SYNTH_CANDIDATES:
            # A small comb absorbs recorder resampling drift
            levels[freq] = max(goertzel_db(mono, rate, freq + offset)
                               for offset in (-4.0, 0.0, 4.0))
        strongest = max(levels.values())
        present = frozenset(freq for freq, db in levels.items()
                            if db >= strongest - SYNTH_PRESENT_MARGIN_DB
                            and db >= SYNTH_PRESENT_FLOOR_DB)
        labels.append(present if present else None)

    # Collapse into runs, dropping sub-threshold runs as boundary noise
    runs = []
    for index, label in enumerate(labels):
        if label is not None and runs and runs[-1][0] == label and index - runs[-1][2] <= SYNTH_MIN_RUN:
            runs[-1][2] = index + 1
        elif label is not None:
            runs.append([label, index, index + 1])
    runs = [run for run in runs if run[2] - run[1] >= SYNTH_MIN_RUN]
    # Dropping a noise blip can leave the same tone split in two: merge
    merged = []
    for run in runs:
        if merged and merged[-1][0] == run[0]:
            merged[-1][2] = run[2]
        else:
            merged.append(run)
    runs = merged

    def label_name(tones):
        return "+".join("{:.0f}Hz".format(f) for f in sorted(tones))

    print("  tone segments detected:")
    for tones, start, end in runs:
        print("    {} at {:.2f}s for {:.2f}s".format(
            label_name(tones), start * window_seconds, (end - start) * window_seconds))
    if not runs:
        print("  FAIL: no tone segments found")
        sys.exit(1)

    failures = []
    for tones, start, end in runs:
        if SYNTH_DATA_FREQ in tones:
            failures.append(
                "{:.0f}Hz heard at the raw data frequency"
                " (channel pitch was not applied)".format(SYNTH_DATA_FREQ))
    sequence = [run[0] for run in runs]
    expected = [tones for tones, _ in SYNTH_EXPECTED]
    if sequence != expected:
        failures.append("segment sequence {} does not match expected {}".format(
            [label_name(t) for t in sequence], [label_name(t) for t in expected]))
        # The most likely single culprit gets its own message
        if len(sequence) >= 5 and SYNTH_FILTERED_FREQ in sequence[-1]:
            failures.append("{:.0f}Hz survived the final segment"
                            " (the lowpass DSP was not applied)".format(SYNTH_FILTERED_FREQ))
    else:
        for (tones, minimum), run in zip(SYNTH_EXPECTED, runs):
            duration = (run[2] - run[1]) * window_seconds
            if duration < minimum:
                failures.append("{} segment {:.2f}s < required {:.2f}s".format(
                    label_name(tones), duration, minimum))
        # The fade segment must show the scheduled volume ramp: the last
        # window well below the first, declining without recovering. The
        # sequence matched above, so this run is the fade by construction.
        fade_run = runs[SYNTH_FADE_INDEX]
        if fade_run[0] == SYNTH_FADE_TONES:
            # The first and last windows straddle the segment seams (partial
            # silence lowers their RMS), so the ramp analysis trims them
            fade_dbs = window_dbs[fade_run[1] + 1:fade_run[2] - 1]
            if len(fade_dbs) >= 6:
                drop = fade_dbs[0] - fade_dbs[-1]
                print("  fade segment: start {:.1f}dB end {:.1f}dB (drop {:.1f}dB)".format(
                    fade_dbs[0], fade_dbs[-1], drop))
                if drop < SYNTH_FADE_DROP_DB:
                    failures.append(
                        "fade segment dropped {:.1f}dB < required {:.1f}dB"
                        " (scheduled fade points were not applied)".format(
                            drop, SYNTH_FADE_DROP_DB))
                recovery = max(fade_dbs[index + 1] - fade_dbs[index]
                               for index in range(len(fade_dbs) - 1))
                if recovery > 3.0:
                    failures.append(
                        "fade segment volume recovered {:.1f}dB mid-ramp"
                        " (not a scheduled fade)".format(recovery))
            else:
                failures.append("fade segment too short to analyze the ramp")

        # Distance attenuation on PcmStream.create3d: both 3D segments are
        # written at the same amplitude and played straight ahead, so the
        # only thing that can separate their levels is the 3D rolloff.
        near_run = runs[SYNTH_3D_NEAR_INDEX]
        far_run = runs[SYNTH_3D_FAR_INDEX]
        near_dbs = window_dbs[near_run[1] + 1:near_run[2] - 1]
        far_dbs = window_dbs[far_run[1] + 1:far_run[2] - 1]
        if len(near_dbs) >= 2 and len(far_dbs) >= 2:
            near_db = sum(near_dbs) / len(near_dbs)
            far_db = sum(far_dbs) / len(far_dbs)
            drop = near_db - far_db
            print("  3D segments: near {:.1f}dB far {:.1f}dB (drop {:.1f}dB)".format(
                near_db, far_db, drop))
            if drop < SYNTH_3D_DROP_DB:
                failures.append(
                    "3D far segment only {:.1f}dB below the near segment,"
                    " required {:.1f}dB (create3d distance attenuation was"
                    " not applied)".format(drop, SYNTH_3D_DROP_DB))
        else:
            failures.append("3D segments too short to compare levels")

    if failures:
        for failure in failures:
            print("  FAIL: " + failure)
        sys.exit(1)
    print("  synth frequency gate: OK")


def main():
    path, options = parse_args(sys.argv[1:])
    channels, rate, pcm = read_wav(path)
    block = channels * 2
    frames = len(pcm) // block
    duration = frames / rate if rate else 0.0
    window_frames = int(rate * WINDOW_MS / 1000)
    window_count = frames // window_frames if window_frames else 0
    window_seconds = WINDOW_MS / 1000.0

    print("  --- Audio profile: {}ch {}Hz, {:.2f}s ---".format(channels, rate, duration))
    if window_count == 0:
        print("  FAIL: no analyzable audio")
        sys.exit(1)

    window_dbs = []
    channel_active = [0.0] * channels
    clip_window_count = 0
    for index in range(window_count):
        start = index * window_frames * block
        chunk = pcm[start:start + window_frames * block]
        samples = struct.unpack("<{}h".format(len(chunk) // 2), chunk)
        window_dbs.append(rms_db(samples))
        window_peak = 0
        for value in samples:
            magnitude = -value if value < 0 else value
            if magnitude > window_peak:
                window_peak = magnitude
        if window_peak >= CLIP_SAMPLE:
            clip_window_count += 1
        for channel in range(channels):
            if rms_db(samples[channel::channels]) > SILENCE_DB:
                channel_active[channel] += window_seconds

    active_indices = [i for i, db in enumerate(window_dbs) if db > SILENCE_DB]
    if not active_indices:
        print("  FAIL: recording is entirely silent")
        sys.exit(1)

    lead = active_indices[0] * window_seconds
    trail = (window_count - 1 - active_indices[-1]) * window_seconds
    active_duration = 0.0
    longest_gap = 0.0
    gap_run = 0
    for index in range(active_indices[0], active_indices[-1] + 1):
        if window_dbs[index] > SILENCE_DB:
            active_duration += window_seconds
            gap_run = 0
        else:
            gap_run += 1
            if gap_run * window_seconds > longest_gap:
                longest_gap = gap_run * window_seconds

    strip = []
    per_second = int(1000 / WINDOW_MS)
    for start in range(0, window_count, per_second):
        second = window_dbs[start:start + per_second]
        strip.append("#" if max(second) > SILENCE_DB else ".")

    print("  leading silence:  {:.2f}s (recorder start to first audio)".format(lead))
    print("  trailing silence: {:.2f}s (last audio to recorder stop)".format(trail))
    print("  active audio:     {:.2f}s".format(active_duration))
    print("  longest internal gap: {:.2f}s".format(longest_gap))
    print("  per-channel active: {}".format(
        " ".join("{:.2f}s".format(value) for value in channel_active)))
    print("  profile (1 char = 1s): {}".format("".join(strip)))

    if options["synth"]:
        synth_gate(channels, rate, pcm, window_count, window_frames, window_dbs)
        return

    if not options["gate"]:
        print("  (profile only - no gating)")
        return

    failures = []
    if active_duration < options["min_active"]:
        failures.append("active audio {:.2f}s < required {:.2f}s".format(
            active_duration, options["min_active"]))
    if longest_gap > options["max_gap"]:
        failures.append("internal silent gap {:.2f}s > allowed {:.2f}s (dropout)".format(
            longest_gap, options["max_gap"]))
    if lead > options["max_lead"]:
        failures.append("leading silence {:.2f}s > allowed {:.2f}s (boot hang?)".format(
            lead, options["max_lead"]))
    live_channels = sum(1 for value in channel_active
                        if value >= options["min_active"] / 2)
    if live_channels < min(options["min_channels"], channels):
        failures.append("only {} of {} channels carry signal".format(
            live_channels, channels))
    if clip_window_count >= CLIP_WINDOWS:
        failures.append("sustained clipping in {} windows".format(clip_window_count))

    if failures:
        for failure in failures:
            print("  FAIL: " + failure)
        sys.exit(1)
    print("  profile gates: OK")


if __name__ == "__main__":
    main()
