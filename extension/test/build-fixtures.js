// Builds a fixture page for every file in extension/catalog/, so the
// extension can be driven offline over every DOM shape the site has:
// function entries with a language selector, tabbed examples, lone
// blocks, per-language variants of one example, and plain text blocks
// with no language class.
//
// The page reproduces fmod.com's structure the way extension/keys.js
// reads it, so the keys computed at runtime are the keys the catalog
// was written under. It also carries a copy of the site's selector
// logic (show and hide every language-classed element, remember the
// pick) and renders content late the way the real SPA does.
// window.__rerender() replaces the content again for idempotency tests.
//
// Usage: node extension/test/build-fixtures.js [outdir]   write the pages
// As a module: require(...).buildPage(name, catalogText) -> html string.
const fs = require('fs');
const path = require('path');

const CATALOG = path.join(__dirname, '..', 'catalog');

const CLASS_OF = {
    'C': 'language-c', 'C++': 'language-cpp', 'C/C++': 'language-c-cpp',
    'C#': 'language-csharp', 'JavaScript': 'language-javascript',
};

function classOf(language) {
    if (CLASS_OF[language]) return CLASS_OF[language];
    // The site classes every block, language-text included. None of
    // these are in the selector's set, so it never toggles them.
    return 'language-' + language;
}

function parseCatalog(text) {
    const entries = [];
    const sections = text.split(/^## /m).slice(1);
    for (const section of sections) {
        const lines = section.split('\n');
        const entry = { key: lines[0].trim(), kind: '', index: -1, heading: '', tabbed: false, blocks: [] };
        const body = lines.slice(1).join('\n');
        for (const line of lines) {
            if (line.startsWith('kind: ')) entry.kind = line.slice(6);
            else if (line.startsWith('index: ')) entry.index = parseInt(line.slice(7), 10);
            else if (line.startsWith('heading: ')) entry.heading = line.slice(9);
            else if (line.startsWith('tabbed: ')) entry.tabbed = line.slice(8) === 'yes';
        }
        const re = /^### (.+?)\n```\w*\n([\s\S]*?)\n?```/gm;
        let match;
        while ((match = re.exec(body)) !== null) {
            entry.blocks.push({ language: match[1], code: match[2] });
        }
        entries.push(entry);
    }
    entries.sort((a, b) => a.index - b.index);
    return entries;
}

function escapeHtml(text) {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

const TAB_LABEL = {
    'language-c': 'C', 'language-cpp': 'C++', 'language-c-cpp': 'C/C++',
    'language-csharp': 'C#', 'language-javascript': 'JS',
};

function highlight(block, display) {
    const cls = classOf(block.language);
    return '<div class="highlight' + (cls ? ' ' + cls : '') + '" style="display: ' + display + ';"><pre>'
        + escapeHtml(block.code) + '</pre></div>';
}

// The site's selectors carry one tab per language, in the site's fixed
// order, and never a C/C++ tab: a language-c-cpp block sits under
// separate C and C++ tabs. A block in a language the site does not
// toggle gets no tab.
function selector(blocks) {
    const order = ['language-c', 'language-cpp', 'language-csharp', 'language-javascript'];
    const langs = new Set();
    for (const block of blocks) {
        const cls = classOf(block.language);
        if (cls === 'language-c-cpp') { langs.add('language-c'); langs.add('language-cpp'); }
        else if (order.includes(cls)) langs.add(cls);
    }
    const parts = ['<div class="language-selector">'];
    for (const cls of order) {
        if (!langs.has(cls)) continue;
        const selected = cls === 'language-cpp' ? ' selected' : '';
        parts.push('<div class="language-tab' + selected + '" data-language="' + cls + '">' + TAB_LABEL[cls] + '</div>');
    }
    parts.push('</div>');
    return parts.join('\n');
}

function renderEntry(entry, parts, state) {
    if (entry.kind === 'function') {
        parts.push('<h2 api="function" id="' + entry.key + '"><a href="#' + entry.key + '">' + entry.key + '</a></h2>');
        parts.push('<p>Summary prose for ' + entry.key + '.</p>');
        parts.push('<p>');
        parts.push('</p>' + selector(entry.blocks));
        parts.push('<p></p>');
        for (const block of entry.blocks) {
            parts.push(highlight(block, classOf(block.language) === 'language-cpp' ? 'block' : 'none'));
        }
        parts.push('<p>Prose after the signature.</p>');
        state.heading = entry.key;
        state.lastLone = false;
        return;
    }
    // The catalog keys examples by the nearest heading text, so the
    // fixture emits a heading whenever the recorded one changes.
    if (entry.heading !== state.heading) {
        state.count += 1;
        parts.push('<h3 id="fixture-h' + state.count + '">' + escapeHtml(entry.heading) + '</h3>');
        state.heading = entry.heading;
        state.lastLone = false;
    }
    // Per-language variants of one example sit right next to each other
    // on the site, so a lone block following a lone block under the
    // same heading gets no prose between.
    const lone = !entry.tabbed && entry.blocks.length === 1;
    const run = state.lastLone && lone;
    if (!run) parts.push('<p>Prose before the example.</p>');
    state.lastLone = lone;
    if (!lone) {
        parts.push(selector(entry.blocks));
        parts.push('<p></p>');
        for (const block of entry.blocks) {
            parts.push(highlight(block, classOf(block.language) === 'language-cpp' ? 'block' : 'none'));
        }
    } else {
        // The site's selector only toggles its own language classes, so
        // a block in any other language starts visible and stays so.
        const cls = classOf(entry.blocks[0].language);
        const toggled = ['language-c', 'language-cpp', 'language-c-cpp', 'language-csharp', 'language-javascript'];
        parts.push(highlight(entry.blocks[0], !cls || cls === 'language-cpp' || !toggled.includes(cls) ? 'block' : 'none'));
    }
}

function buildPage(name, catalogText) {
    const entries = parseCatalog(catalogText);
    // Every page of the docs book carries "manual-content api", the
    // guides included, so the site's selector logic runs on all of them.
    const parts = [];
    const state = { heading: null, count: 0 };
    parts.push('<div id="Documentation"><div class="documentation-content"><div class="manual-content api">');
    parts.push('<h1>' + escapeHtml(name) + ' fixture</h1>');
    for (const entry of entries) renderEntry(entry, parts, state);
    parts.push('</div></div></div>');
    const content = parts.join('\n');
    return [
        '<!doctype html>',
        '<html>',
        '<head>',
        '<meta charset="utf-8">',
        '<title>' + escapeHtml(name) + ' fixture</title>',
        '<style>',
        '.language-selector { display: flex; gap: 4px; }',
        '.language-tab { padding: 2px 8px; border: 1px solid #999; cursor: pointer; }',
        '.language-tab.selected { background: #333; color: #fff; }',
        '.highlight { border: 1px solid #b3b3b3; background: #f1f1f1; padding: 6px; }',
        '</style>',
        '</head>',
        '<body class="specificity">',
        '<div id="app"></div>',
        '<script>',
        'var CONTENT = ' + JSON.stringify(content) + ';',
        // The site's selector logic, reproduced from fmod.com's own
        // bundle: blocks are snapshotted at init, the stored language is
        // clamped to what the page offers (and the clamped value written
        // back), language-c-cpp blocks show under C and C++, and a
        // language-all block or pick is always visible.
        "var KNOWN = ['language-c', 'language-cpp', 'language-c-cpp', 'language-csharp', 'language-javascript'];",
        'var siteTabs = null, siteBlocks = null, siteLangs = null;',
        'function blockVisible(block, lang) {',
        "  if (lang === 'language-all' || block.classList.contains('language-all')) return true;",
        "  if ((lang === 'language-c' || lang === 'language-cpp') && block.classList.contains('language-c-cpp')) return true;",
        '  return block.classList.contains(lang);',
        '}',
        'function selectLanguage(lang) {',
        '  if (siteBlocks == null) return;',
        "  window.localStorage.setItem('FMOD.Documents.selected-language', lang);",
        '  if (siteLangs.length > 0 && siteLangs.indexOf(lang) < 0) lang = siteLangs[0];',
        '  for (var i = 0; i < siteTabs.length; i++) {',
        "    siteTabs[i].classList.toggle('selected', siteTabs[i].getAttribute('data-language') === lang);",
        '  }',
        '  for (var j = 0; j < siteBlocks.length; j++) {',
        "    siteBlocks[j].style.display = blockVisible(siteBlocks[j], lang) ? 'block' : 'none';",
        '  }',
        "  window.localStorage.setItem('FMOD.Documents.selected-language', lang);",
        '}',
        'function initLanguageSelector() {',
        "  var root = document.querySelector('div.manual-content.api');",
        '  if (!root) return;',
        "  siteTabs = root.getElementsByClassName('language-tab');",
        '  for (var i = 0; i < siteTabs.length; i++) {',
        "    siteTabs[i].onclick = function () { selectLanguage(this.getAttribute('data-language')); };",
        '  }',
        "  siteBlocks = root.querySelectorAll(KNOWN.map(function (k) { return '.' + k; }).join(', '));",
        '  siteLangs = [];',
        '  KNOWN.forEach(function (k) {',
        "    if (root.querySelector('.' + k) != null) siteLangs.push(k);",
        '  });',
        "  if (siteLangs.indexOf('language-c-cpp') >= 0) {",
        "    if (siteLangs.indexOf('language-c') < 0) siteLangs.push('language-c');",
        "    if (siteLangs.indexOf('language-cpp') < 0) siteLangs.push('language-cpp');",
        '  }',
        "  var saved = window.localStorage.getItem('FMOD.Documents.selected-language');",
        "  if (saved == null) saved = 'language-cpp';",
        '  selectLanguage(saved);',
        '}',
        'window.__rerender = function () {',
        "  document.getElementById('app').innerHTML = CONTENT;",
        '  initLanguageSelector();',
        '};',
        'window.setTimeout(window.__rerender, 200);',
        '</script>',
        '</body>',
        '</html>',
    ].join('\n');
}

function buildAll() {
    const pages = {};
    for (const file of fs.readdirSync(CATALOG).sort()) {
        if (!file.endsWith('.md')) continue;
        const name = file.slice(0, -3);
        pages[name] = buildPage(name, fs.readFileSync(path.join(CATALOG, file), 'utf8'));
    }
    return pages;
}

module.exports = { buildPage, buildAll, parseCatalog };

if (require.main === module) {
    const outdir = process.argv[2] || path.join(__dirname, 'fixtures');
    fs.mkdirSync(outdir, { recursive: true });
    const pages = buildAll();
    for (const name of Object.keys(pages)) {
        fs.writeFileSync(path.join(outdir, name + '.html'), pages[name]);
    }
    console.log('wrote ' + Object.keys(pages).length + ' fixture pages to ' + outdir);
}
