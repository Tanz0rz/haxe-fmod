# haxefmod for FMOD docs

A browser extension that adds a **Haxe** tab next to C, C++, C#, and JS on every function of the [FMOD API reference](https://www.fmod.com/docs/2.03/api/welcome.html). The tab shows the haxefmod method that wraps the function, its Haxe signature, the first line of its documentation, related helpers, and HTML5 caveats. Functions haxefmod does not expose say so.

FMOD's own reference stays the place to read what a function does. The tab only adds the Haxe side.

## Install

Chrome, Edge, Brave, and Opera: install from the Chrome Web Store (listing pending).

Firefox: install from addons.mozilla.org (listing pending).

Any browser with a userscript manager: install `haxefmod-fmod-docs.user.js` from this directory.

### Unpacked, for development

Chromium browsers: open `chrome://extensions`, turn on Developer mode, choose "Load unpacked", and pick this directory.

Firefox needs its own manifest (a background script instead of a service worker, plus the add-on id). Run `python3 extension/package.py --unpacked`, then open `about:debugging#/runtime/this-firefox`, choose "Load Temporary Add-on", and pick `extension/dist/firefox/manifest.json`.

## How it works

`content.js` runs on `fmod.com/docs` pages. The site renders each function as a heading with an id derived from the C++ name (`studio_eventinstance_start`), a language selector, and one signature block per language. The script appends a fifth tab and block, keyed by that id, using `bindings-data.js`.

`bindings-data.js` is generated. `ci/haxe-bindings.py` reads the HashLink shim to learn which FMOD function each native binding calls, reads the Haxe sources to learn which public method calls each native binding, and reads the web shim for calls that report `FMOD_ERR_UNSUPPORTED`. Regenerate it after changing the bindings:

```bash
python3 ci/haxe-bindings.py
```

The same table renders the coverage page of the documentation site.

Every other code block on the site (type definitions, guide examples, lone C++ blocks) is inventoried in `catalog/<page>.md`, written by `test/catalog-site.js` from the live site: one entry per block under a stable key (the function id, or the heading the block sits under) with the snippet of every language the site shows. The Haxe side lives in `haxe/<page>.md` under the same keys, one section per block with a `verdict:` line (`bound` with a Haxe fence or a `Type:` line that copies the declaration out of the sources, or `cannot`, `library`, `covered` with a reason). `ci/haxe-catalog.py` compiles them into `examples-data.js` and fails when any block on the site has no section, a section has no verdict, a declaration lacks a member the site's snippet declares, or an example uses none of the Haxe methods that reach a call the snippet makes. The format is documented at the top of that script.

```bash
python3 ci/haxe-catalog.py
python3 ci/check-readme-snippets.py extension/haxe extension/functions.md
```

A lone block on a page that has a language selector of the site's own is already governed by it, since the site shows and hides every language-classed block on the page at once. The Haxe translation for such a block just joins that toggle: it is inserted as a `language-haxe` block with no extra tab strip, and appears when Haxe is picked on any selector of the page. An example the site repeats once per language as adjacent lone blocks counts as one unit under the first block's key, with one Haxe translation. Only a page with no selector at all (the guides and platform pages) gets an added strip per lone unit, with a tab for the block's language and the Haxe tab, since there is nowhere else to pick Haxe from. `keys.js` computes the block keys and the unit folding at runtime the same way the crawler did.

Two more checks keep the Haxe side honest. `ci/haxe-catalog.py` compares each fence against the site's own snippet (string and number literals, the order of FMOD calls, statement count), and a difference a reviewer has judged right is silenced in place with a `waive: <rule> <reason>` line that itself fails when the check stops firing. `ci/example-ledger.py` records a review stamp per entry, a hash over the catalog snippet and the Haxe section, so a site edit or a rules change puts exactly the touched entries back on the review list:

```bash
python3 ci/example-ledger.py --status
python3 ci/example-ledger.py --next 5
python3 ci/example-ledger.py --stamp <page> "<key>"
```

Clicking the toolbar icon opens the FMOD API reference. The extension asks for no permissions beyond running on fmod.com documentation pages and makes no network requests. The data ships inside the package.

## Test

```bash
NODE_PATH=/path/to/node_modules xvfb-run node extension/test/run.js
NODE_PATH=/path/to/node_modules node extension/test/run.js --headless --all
NODE_PATH=/path/to/node_modules xvfb-run node extension/test/run.js --live
```

The default run serves `test/fixture.html` in place of fmod.com and checks the tab flow. `--all` also builds a fixture from every `catalog/` page (`test/build-fixtures.js`) and holds the tab invariants on each: one Haxe tab per unit, no strip standing over blocks that are all hidden, one Haxe block per unit when Haxe is picked, and nothing added on a re-render. `--headless` uses Chromium's new headless mode, which loads extensions without a display. `--live` runs the base checks against the real site.

## When fmod.com changes

The weekly `docs-canary` workflow crawls the live site into the catalog format and fails when it differs from `catalog/`, naming every code location that was added, removed, or edited. Run it by hand with:

```bash
NODE_PATH=/path/to/node_modules node extension/test/catalog-site.js --check
```

On a machine where the site will not render, `--check --from <dir>` reads saved content fragments instead (one `<page>.html` per file from the docs content origin, `https://d1s9dnlmdewoh1.cloudfront.net/2.03/api/<page>.html`), which carry the same markup the site injects.

Refresh the catalog, then bring `haxe/` and `functions.md` in line until `ci/haxe-catalog.py --check` passes. The refresh changes the hashes of the touched entries, so `ci/example-ledger.py --status` lists exactly what needs a fresh review, and the docs workflow stays red until every entry is fixed or stamped again:

```bash
NODE_PATH=/path/to/node_modules node extension/test/catalog-site.js --update
python3 ci/haxe-catalog.py
python3 ci/example-ledger.py --status
```

Functions haxefmod does not expose are listed with their reasons on the documentation site's "Unsupported functions" page, generated from `functions.md` by `ci/haxe-bindings.py`. Adding a binding means removing its section there, at which point the generator picks the new method up from the sources.

## Package for the stores

```bash
python3 extension/package.py
```

This writes `extension/dist/haxefmod-fmod-docs-chrome-<version>.zip` for the Chrome Web Store (and Edge, Brave, Opera) and `haxefmod-fmod-docs-firefox-<version>.zip` for addons.mozilla.org. The two differ only in the manifest: Firefox runs the background file as a script and carries the add-on id, which Chrome would warn about.
