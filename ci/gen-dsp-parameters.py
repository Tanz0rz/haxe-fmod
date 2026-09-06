#!/usr/bin/env python3
"""Generates haxefmod/core/DspParameters.hx from fmod_dsp_effects.h.

FMOD declares one parameter index enum per built-in effect
(FMOD_DSP_LOWPASS, FMOD_DSP_CHANNELMIX, and so on). Each becomes one
`enum abstract Dsp<Effect>(Int)` so a game writes
dsp.setParameter(DspLowpass.CUTOFF, 800) instead of a magic number. The
same script writes tests/native/faxe_dsp_parameters.h, an X macro list of
every value, which tests/native/test_faxe_dspparams.c asserts against
the SDK headers in CI.

The value enums an effect parameter accepts (FMOD_DSP_PAN_MODE_TYPE and
friends) live in haxefmod/core/DspEnums.hx and are not handled here.

Run: python3 ci/gen-dsp-parameters.py          rewrite both files
     python3 ci/gen-dsp-parameters.py --check  fail if either is out of date

The header is read from $FMOD_SDK/api/core/inc/fmod_dsp_effects.h, or
from the SDK cache path below when FMOD_SDK is unset.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SDK = "/workspace/fmod/fmod-sdk-cache/sdk/2.03.12/linux"
HAXE_OUT = os.path.join(ROOT, "haxefmod", "core", "DspParameters.hx")
C_OUT = os.path.join(ROOT, "tests", "native", "faxe_dsp_parameters.h")

# Effect name in the header, Haxe abstract name, and the effect as it is
# described in the doc comment. Header order is kept for the output.
EFFECTS = {
    "OSCILLATOR": ("DspOscillator", "oscillator generator"),
    "LOWPASS": ("DspLowpass", "lowpass effect"),
    "ITLOWPASS": ("DspItLowpass", "IT lowpass effect"),
    "HIGHPASS": ("DspHighpass", "highpass effect"),
    "ECHO": ("DspEcho", "echo effect"),
    "FADER": ("DspFader", "fader effect"),
    "FLANGE": ("DspFlange", "flange effect"),
    "DISTORTION": ("DspDistortion", "distortion effect"),
    "NORMALIZE": ("DspNormalize", "normalize effect"),
    "LIMITER": ("DspLimiter", "limiter effect"),
    "PARAMEQ": ("DspParamEq", "parametric EQ effect"),
    "MULTIBAND_EQ": ("DspMultibandEq", "multiband EQ effect"),
    "MULTIBAND_DYNAMICS": ("DspMultibandDynamics", "multiband dynamics effect"),
    "PITCHSHIFT": ("DspPitchShift", "pitch shift effect"),
    "CHORUS": ("DspChorus", "chorus effect"),
    "ITECHO": ("DspItEcho", "IT echo effect"),
    "COMPRESSOR": ("DspCompressor", "compressor effect"),
    "SFXREVERB": ("DspSfxReverb", "SFX reverb effect"),
    "LOWPASS_SIMPLE": ("DspLowpassSimple", "simple lowpass effect"),
    "DELAY": ("DspDelay", "delay effect"),
    "TREMOLO": ("DspTremolo", "tremolo effect"),
    "SEND": ("DspSend", "send effect"),
    "RETURN": ("DspReturn", "return effect"),
    "HIGHPASS_SIMPLE": ("DspHighpassSimple", "simple highpass effect"),
    "PAN": ("DspPan", "pan effect"),
    "THREE_EQ": ("DspThreeEq", "three band EQ effect"),
    "FFT": ("DspFft", "FFT analyser"),
    "LOUDNESS_METER": ("DspLoudnessMeter", "loudness meter"),
    "CONVOLUTION_REVERB": ("DspConvolutionReverb", "convolution reverb effect"),
    "CHANNELMIX": ("DspChannelMix", "channel mix effect"),
    "TRANSCEIVER": ("DspTransceiver", "transceiver effect"),
    "OBJECTPAN": ("DspObjectPan", "object pan effect"),
}

# Enums in the header that are values rather than parameter indices.
# FMOD_DSP_TYPE is the effect list and lives in DspType.hx.
VALUE_ENUM = re.compile(r"^FMOD_DSP_(TYPE|\w+_(TYPE|MODE|OUTPUT|SPEAKERMODE))$")

TYPEDEF = re.compile(r"typedef enum(?:\s+\w+)?\s*\{(.*?)\}\s*(FMOD_DSP_\w+)\s*;", re.S)
ENTRY = re.compile(r"^\s*(FMOD_DSP_\w+)\s*(?:=\s*(-?\w+))?\s*,?\s*(?:/\*.*?\*/)?\s*$")


def header_path():
    sdk = os.environ.get("FMOD_SDK", DEFAULT_SDK)
    return os.path.join(sdk, "api", "core", "inc", "fmod_dsp_effects.h")


def parse(text):
    """Returns [(effect, [(name, value), ...])] in header order."""
    enums = []
    seen = set()
    for match in TYPEDEF.finditer(text):
        body, enum_name = match.groups()
        if VALUE_ENUM.match(enum_name):
            continue
        effect = enum_name[len("FMOD_DSP_"):]
        if effect not in EFFECTS:
            print(f"FAIL: {enum_name} is not in the EFFECTS table of {os.path.basename(__file__)}")
            sys.exit(1)
        prefix = f"FMOD_DSP_{effect}_"
        values = []
        next_value = 0
        for line in body.splitlines():
            line = re.sub(r"/\*.*?\*/", "", line).strip()
            if not line:
                continue
            entry = ENTRY.match(line)
            if not entry or not entry.group(1).startswith(prefix):
                print(f"FAIL: cannot read '{line}' in {enum_name}")
                sys.exit(1)
            if entry.group(2) is not None:
                next_value = int(entry.group(2), 0)
            values.append((entry.group(1)[len(prefix):], next_value))
            next_value += 1
        enums.append((effect, values))
        seen.add(effect)
    missing = [e for e in EFFECTS if e not in seen]
    if missing:
        print(f"FAIL: the header has no parameter enum for {', '.join(missing)}")
        sys.exit(1)
    return enums


def haxe_name(value_name):
    # A Haxe identifier cannot start with a digit, so FMOD_DSP_PAN_2D_EXTENT
    # keeps the underscore from the prefix and becomes _2D_EXTENT.
    return "_" + value_name if value_name[0].isdigit() else value_name


def build_haxe(enums):
    lines = [
        "package haxefmod.core;",
        "",
        "/*",
        " * Generated by ci/gen-dsp-parameters.py from fmod_dsp_effects.h.",
        " * Do not edit, rerun the script.",
        " *",
        " * The parameter indices of the built-in DSP effects, one enum per",
        " * effect. Each converts to Int, so dsp.setParameter(DspLowpass.CUTOFF, 800)",
        " * works with every Dsp parameter setter and getter. The values a",
        " * parameter accepts (pan modes, FFT windows) are in DspEnums.hx.",
        " */",
        "",
    ]
    for effect, values in enums:
        abstract_name, description = EFFECTS[effect]
        digit_names = [v for v, _ in values if v[0].isdigit()]
        doc = f"/** FMOD_DSP_{effect}, parameter indices of the {description}."
        if digit_names:
            doc += " Names that start with a digit keep a leading underscore, since a Haxe identifier cannot start with one."
        doc += " */"
        lines.append(doc)
        lines.append(f"enum abstract {abstract_name}(Int) from Int to Int {{")
        for value_name, value in values:
            lines.append(f"    var {haxe_name(value_name)} = {value};")
        lines.append("}")
        lines.append("")
    return "\n".join(lines)


def build_c(enums):
    lines = [
        "/* Generated by ci/gen-dsp-parameters.py from fmod_dsp_effects.h.",
        " * Do not edit, rerun the script.",
        " *",
        " * FAXE_DSP_PARAMETERS(X) expands X(haxe enum, haxe name, FMOD",
        " * constant, value) once per parameter index declared in",
        " * haxefmod/core/DspParameters.hx. */",
        "#ifndef FAXE_DSP_PARAMETERS_H",
        "#define FAXE_DSP_PARAMETERS_H",
        "",
        f"#define FAXE_DSP_PARAMETER_ENUMS {len(enums)}",
        f"#define FAXE_DSP_PARAMETER_VALUES {sum(len(v) for _, v in enums)}",
        "",
        "#define FAXE_DSP_PARAMETERS(X) \\",
    ]
    for effect, values in enums:
        abstract_name = EFFECTS[effect][0]
        for value_name, value in values:
            lines.append(f"    X({abstract_name}, {haxe_name(value_name)}, FMOD_DSP_{effect}_{value_name}, {value}) \\")
    lines[-1] = lines[-1][:-2]
    lines += ["", "#endif"]
    return "\n".join(lines) + "\n"


def main():
    with open(header_path(), encoding="utf-8") as fh:
        enums = parse(fh.read())
    outputs = {HAXE_OUT: build_haxe(enums), C_OUT: build_c(enums)}
    if "--check" in sys.argv:
        stale = []
        for path, text in outputs.items():
            try:
                with open(path, encoding="utf-8") as fh:
                    current = fh.read()
            except FileNotFoundError:
                current = None
            if current != text:
                stale.append(os.path.relpath(path, ROOT))
        if stale:
            print(f"FAIL: out of date, rerun ci/gen-dsp-parameters.py: {', '.join(stale)}")
            sys.exit(1)
        print(f"OK: {len(enums)} DSP parameter enums, {sum(len(v) for _, v in enums)} values, in lockstep with the header")
        return
    for path, text in outputs.items():
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"wrote {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
