#!/bin/bash
# Prebuild validation script to check environment variables
# Called by lime before processing assets
# Usage: prebuild-validate-env.sh <target>

TARGET="$1"

# For HTML5 builds, FMOD_SDK_WEB must be set
if [ "$TARGET" = "html5" ]; then
  if [ -z "$FMOD_SDK_WEB" ]; then
    echo ""
    echo "============================================================"
    echo "  ERROR: FMOD_SDK_WEB environment variable is not set."
    echo ""
    echo "  HTML5 builds require the FMOD Engine SDK for HTML5."
    echo ""
    echo "  1. Download FMOD Engine 2.03.12 for HTML5 from:"
    echo "     https://www.fmod.com/download"
    echo ""
    echo "  2. Extract it and set FMOD_SDK_WEB:"
    echo ""
    echo "     export FMOD_SDK_WEB=/path/to/fmodstudioapi20312html5"
    echo ""
    echo "     Or on Windows:"
    echo "     set FMOD_SDK_WEB=C:\\path\\to\\fmodstudioapi20312html5"
    echo ""
    echo "  3. Run 'haxelib run haxefmod doctor' to verify your setup."
    echo ""
    echo "============================================================"
    echo ""
    exit 1
  fi
fi

# For native builds (C++/HL), FMOD_SDK must be set
# (This check is also in postbuild-copy-fmod.sh, but checking here gives earlier feedback)
if [ "$TARGET" != "html5" ]; then
  if [ -z "$FMOD_SDK" ]; then
    echo ""
    echo "============================================================"
    echo "  ERROR: FMOD_SDK environment variable is not set."
    echo ""
    echo "  Run 'haxelib run haxefmod doctor' for setup instructions."
    echo "============================================================"
    echo ""
    exit 1
  fi
fi

exit 0
