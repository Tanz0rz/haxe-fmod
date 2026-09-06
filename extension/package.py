#!/usr/bin/env python3
"""Builds the store packages: one zip for Chromium browsers and one for
Firefox, from the same files.

extension/manifest.json is the Chromium form (a background service
worker, no browser-specific keys, since Chrome warns about keys it does
not know). Firefox runs the background file as a script and needs the
gecko id, so its manifest is derived here rather than kept by hand.

Run: python3 extension/package.py            writes extension/dist/*.zip
     python3 extension/package.py --unpacked  also writes extension/dist/firefox/
                                              for about:debugging loads
"""

import json
import os
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(HERE, "dist")
FILES = ["background.js", "content.js", "content.css", "bindings-data.js", "examples-data.js",
         "icon16.png", "icon32.png", "icon48.png", "icon128.png"]
GECKO_ID = "haxefmod-docs@haxe-fmod.tanz0rz.github.io"


def firefox_manifest(manifest):
    firefox = json.loads(json.dumps(manifest))
    firefox["background"] = {"scripts": [manifest["background"]["service_worker"]]}
    firefox["browser_specific_settings"] = {"gecko": {"id": GECKO_ID, "strict_min_version": "109.0"}}
    return firefox


def write_zip(path, manifest):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("manifest.json", json.dumps(manifest, indent=2) + "\n")
        for name in FILES:
            zf.write(os.path.join(HERE, name), name)


def main():
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as fh:
        manifest = json.load(fh)
    version = manifest["version"]
    os.makedirs(DIST, exist_ok=True)
    chrome = os.path.join(DIST, f"haxefmod-fmod-docs-chrome-{version}.zip")
    firefox = os.path.join(DIST, f"haxefmod-fmod-docs-firefox-{version}.zip")
    write_zip(chrome, manifest)
    write_zip(firefox, firefox_manifest(manifest))
    print("wrote " + os.path.relpath(chrome, HERE) + " and " + os.path.relpath(firefox, HERE))
    if "--unpacked" in sys.argv[1:]:
        unpacked = os.path.join(DIST, "firefox")
        shutil.rmtree(unpacked, ignore_errors=True)
        os.makedirs(unpacked)
        for name in FILES:
            shutil.copy(os.path.join(HERE, name), unpacked)
        with open(os.path.join(unpacked, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(firefox_manifest(manifest), fh, indent=2)
            fh.write("\n")
        print("wrote dist/firefox/ for about:debugging")
    return 0


if __name__ == "__main__":
    sys.exit(main())
