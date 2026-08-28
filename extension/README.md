# haxefmod for FMOD docs

A browser extension that adds a **Haxe** tab next to C, C++, C#, and JS on every function of the [FMOD API reference](https://www.fmod.com/docs/2.03/api/welcome.html). The tab shows the haxefmod method that wraps the function, its Haxe signature, the first line of its documentation, related helpers, and HTML5 caveats. Functions haxefmod does not expose say so.

FMOD's own reference stays the place to read what a function does. The tab only adds the Haxe side.

## Install

Chrome, Edge, Brave, and Opera: install from the Chrome Web Store (listing pending).

Firefox: install from addons.mozilla.org (listing pending).

Any browser with a userscript manager: install `haxefmod-fmod-docs.user.js` from this directory.

### Unpacked, for development

Chromium browsers: open `chrome://extensions`, turn on Developer mode, choose "Load unpacked", and pick this directory.

Firefox: open `about:debugging#/runtime/this-firefox`, choose "Load Temporary Add-on", and pick `manifest.json`.

## How it works

`content.js` runs on `fmod.com/docs` pages. The site renders each function as a heading with an id derived from the C++ name (`studio_eventinstance_start`), a language selector, and one signature block per language. The script appends a fifth tab and block, keyed by that id, using `bindings-data.js`.

`bindings-data.js` is generated. `ci/haxe-bindings.py` reads the HashLink shim to learn which FMOD function each native binding calls, reads the Haxe sources to learn which public method calls each native binding, and reads the web shim for calls that report `FMOD_ERR_UNSUPPORTED`. Regenerate it after changing the bindings:

```bash
python3 ci/haxe-bindings.py
```

The same table renders the coverage page of the documentation site.

The extension asks for no permissions beyond running on fmod.com documentation pages and makes no network requests. The data ships inside the package.

## Test

```bash
NODE_PATH=/path/to/node_modules xvfb-run node extension/test/run.js
NODE_PATH=/path/to/node_modules xvfb-run node extension/test/run.js --live
```

The default run serves `test/fixture.html` in place of fmod.com and checks the tab flow. `--live` runs the same checks against the real site.

## Package for the stores

```bash
cd extension && zip -r ../haxefmod-fmod-docs.zip manifest.json content.js content.css bindings-data.js icon48.png icon128.png
```

The same zip uploads to both the Chrome Web Store and addons.mozilla.org.
