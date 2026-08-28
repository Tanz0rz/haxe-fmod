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

Guide pages carry code examples that are not function entries (tabbed C, C++, C#, JS samples, and lone C++ blocks). Their Haxe versions are written by hand in `examples/<page>.md`, one file per fmod.com page, keyed by the example's position on the page. `ci/haxe-examples.py` compiles them into `examples-data.js`, and the docs workflow compiles every Haxe fence in them against the library:

```bash
python3 ci/haxe-examples.py
python3 ci/check-readme-snippets.py extension/examples
```

Lone C++ blocks have no language selector on fmod.com, so the extension adds one with a C++ tab and the Haxe tab. The format of the example files is documented at the top of `ci/haxe-examples.py`.

Clicking the toolbar icon opens the FMOD API reference. The extension asks for no permissions beyond running on fmod.com documentation pages and makes no network requests. The data ships inside the package.

## Test

```bash
NODE_PATH=/path/to/node_modules xvfb-run node extension/test/run.js
NODE_PATH=/path/to/node_modules xvfb-run node extension/test/run.js --live
```

The default run serves `test/fixture.html` in place of fmod.com and checks the tab flow. `--live` runs the same checks against the real site.

## When fmod.com changes

The tab is keyed by function heading ids and by the position of code examples on each page, so an edit on fmod.com can move or drop a tab. `test/site-snapshot.json` records those keys for every page of the API reference, and the weekly `docs-canary` workflow crawls the live site and fails when they differ, listing every added, removed, or moved function and example. Run it by hand with:

```bash
NODE_PATH=/path/to/node_modules node extension/test/crawl-site.js --check
```

After fixing `examples/` and `functions.md` to match, refresh the snapshot:

```bash
NODE_PATH=/path/to/node_modules node extension/test/crawl-site.js --update
```

Functions haxefmod does not expose are listed with their reasons on the documentation site's "Unsupported functions" page, generated from `functions.md` by `ci/haxe-bindings.py`. Adding a binding means removing its section there, at which point the generator picks the new method up from the sources.

## Package for the stores

```bash
cd extension && zip -r ../haxefmod-fmod-docs.zip manifest.json background.js content.js content.css bindings-data.js examples-data.js icon16.png icon32.png icon48.png icon128.png
```

The same zip uploads to both the Chrome Web Store and addons.mozilla.org.
