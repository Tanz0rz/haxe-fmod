// Writes the catalog of every code location on fmod.com's API reference.
//
// The extension shows a Haxe tab beside every code block on the docs
// site. To know that every block is covered, and covered with the right
// code, this crawler walks every page reachable from welcome.html and
// records each block under its key (see extension/keys.js) with the
// snippet of every language the site shows for it, into
// extension/catalog/<page>.md. The Haxe side in extension/haxe/<page>.md
// is written against those keys and checked by ci/haxe-catalog.py.
//
// Usage: node extension/test/catalog-site.js --update   rewrite the catalog
//        node extension/test/catalog-site.js --check    crawl and exit 1 when
//                                                       the site differs from
//                                                       the committed catalog
//
// --from <dir> reads the pages from saved content fragments (one
// <page>.html per file, as served by the docs content origin) instead
// of crawling the live site, for machines where the site itself does
// not render. The fragments carry the same markup the SPA injects.
//
// Needs the playwright package on NODE_PATH. Runs headless, no extension
// involved. Set CHROMIUM_PATH to use a system Chromium.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE = 'https://www.fmod.com/docs/2.03/api/';
const CATALOG = path.join(__dirname, '..', 'catalog');
const KEYS = path.join(__dirname, '..', 'keys.js');
const mode = process.argv.includes('--update') ? 'update' : process.argv.includes('--check') ? 'check' : null;
const fromIndex = process.argv.indexOf('--from');
const fromDir = fromIndex >= 0 ? process.argv[fromIndex + 1] : null;
if (!mode || (fromIndex >= 0 && !fromDir)) {
    console.error('usage: node extension/test/catalog-site.js --update | --check [--from <dir>]');
    process.exit(2);
}

const LANGUAGES = {
    'language-c': 'C', 'language-cpp': 'C++', 'language-c-cpp': 'C/C++',
    'language-csharp': 'C#', 'language-javascript': 'JavaScript',
};

function fenceFor(language) {
    return { 'C': 'c', 'C++': 'cpp', 'C/C++': 'cpp', 'C#': 'csharp', 'JavaScript': 'javascript' }[language] || 'text';
}

function render(page, units) {
    const lines = ['# ' + page, ''];
    for (const unit of units) {
        lines.push('## ' + unit.key);
        lines.push('kind: ' + unit.kind);
        lines.push('index: ' + unit.index);
        if (unit.kind !== 'function') lines.push('heading: ' + unit.heading);
        // An example under a selector of its own, however few languages
        // it offers, so a single-language one is not mistaken for a
        // lone block.
        if (unit.kind !== 'function' && unit.tabbed) lines.push('tabbed: yes');
        lines.push('');
        for (const block of unit.blocks) {
            lines.push('### ' + block.language);
            lines.push('```' + fenceFor(block.language));
            lines.push(block.code.replace(/\s+$/, ''));
            lines.push('```');
            lines.push('');
        }
    }
    return lines.join('\n');
}

// Pages the committed catalog records at least one tabbed unit for.
// Every one of them must still render a tab strip.
function tabbedPages() {
    const names = new Set();
    for (const file of fs.readdirSync(CATALOG)) {
        if (!file.endsWith('.md')) continue;
        const text = fs.readFileSync(path.join(CATALOG, file), 'utf8');
        if (/^kind: function$/m.test(text) || /^tabbed: yes$/m.test(text)) names.add(file.slice(0, -3));
    }
    return names;
}

const TABBED_PAGES = tabbedPages();
const markupDrift = [];

async function crawl() {
    const launch = { args: ['--no-sandbox'] };
    if (process.env.CHROMIUM_PATH) launch.executablePath = process.env.CHROMIUM_PATH;
    const browser = await chromium.launch(launch);
    const context = await browser.newContext();
    if (fromDir) {
        // Everything comes from the fragment directory, nothing from
        // the network: a fragment's subresources (styles, scripts,
        // trackers) play no part in the markup being cataloged.
        await context.route('**/*', route => {
            const url = route.request().url();
            if (!url.startsWith(BASE)) return route.abort();
            const file = path.join(fromDir, url.split('/').pop().split('#')[0]);
            if (fs.existsSync(file) && file.endsWith('.html')) {
                route.fulfill({ status: 200, contentType: 'text/html', body: fs.readFileSync(file, 'utf8') });
            } else {
                route.fulfill({ status: 404, contentType: 'text/plain', body: 'missing fragment' });
            }
        });
    }
    const page = await context.newPage();
    const keysSource = fs.readFileSync(KEYS, 'utf8');
    const queue = fromDir
        ? fs.readdirSync(fromDir).filter(f => f.endsWith('.html')).sort()
        : ['welcome.html'];
    const seen = new Set(queue);
    const pages = {};
    while (queue.length) {
        const name = queue.shift();
        try {
            await page.goto(BASE + name, { waitUntil: fromDir ? 'load' : 'networkidle', timeout: 60000 });
            // The markup is what gets cataloged, layout does not matter
            // (a page whose styles did not load can report zero height).
            await page.waitForSelector('div.manual-content', { state: 'attached', timeout: 30000 });
        } catch (e) {
            console.error('skip ' + name + ': ' + e.message.split('\n')[0]);
            continue;
        }
        if (!fromDir) {
            const links = await page.evaluate(() => Array.from(document.querySelectorAll('a[href]'))
                .map(a => a.getAttribute('href'))
                .filter(h => h && /^[a-z0-9-]+\.html/.test(h))
                .map(h => h.split('#')[0]));
            for (const link of links) if (!seen.has(link)) { seen.add(link); queue.push(link); }
        }

        await page.evaluate(keysSource);
        // The extension hangs the Haxe tab off the site's own tab strip
        // and styles it inside the site's content container. A rename on
        // their side breaks the tab without changing a single snippet,
        // so the markup is checked here beside the snippets.
        const markup = await page.evaluate((shell) => {
            const problems = [];
            const root = document.querySelector('div.manual-content');
            if (shell) {
                if (!document.querySelector('#Documentation')) problems.push('no #Documentation container');
                else if (!document.querySelector('#Documentation div.documentation-content')) {
                    problems.push('no div.documentation-content under #Documentation');
                }
            }
            const selectors = root ? root.querySelectorAll('div.language-selector') : [];
            for (const selector of selectors) {
                const tabs = selector.querySelectorAll('div.language-tab');
                if (!tabs.length) {
                    problems.push('a div.language-selector holds no div.language-tab');
                    break;
                }
                let missing = 0;
                let unprefixed = 0;
                for (const tab of tabs) {
                    const value = tab.getAttribute('data-language');
                    if (value === null) missing++;
                    else if (value.indexOf('language-') !== 0) unprefixed++;
                }
                if (missing) { problems.push('a div.language-tab carries no data-language attribute'); break; }
                if (unprefixed) { problems.push('a data-language value does not start with "language-"'); break; }
            }
            return { problems, selectors: selectors.length, blocks: root ? root.querySelectorAll('div.highlight').length : 0 };
        }, !fromDir);
        // A page whose blocks all sit under tab strips must have found
        // strips. Zero of them with blocks present means the class is gone.
        if (markup.blocks && !markup.selectors && TABBED_PAGES.has(name.replace(/\.html$/, ''))) {
            markup.problems.push('no div.language-selector on a page that had tab strips');
        }
        if (markup.problems.length) markupDrift.push(...markup.problems.map(p => name.replace(/\.html$/, '') + ': ' + p));
        const units = await page.evaluate((languages) => {
            const root = document.querySelector('div.manual-content');
            return window.haxefmodKeys.units(root).map(unit => {
                const blocks = [];
                const languageOf = (node) => {
                    for (const cls of node.classList) if (languages[cls]) return languages[cls];
                    for (const cls of node.classList) if (cls.indexOf('language-') === 0) return cls.slice('language-'.length);
                    return 'text';
                };
                if (unit.tabbed) {
                    let n = unit.node.nextElementSibling;
                    while (n && (n.classList.contains('highlight') || (n.tagName === 'P' && n.textContent.trim() === ''))) {
                        if (n.classList.contains('highlight')) blocks.push({ language: languageOf(n), code: n.textContent });
                        n = n.nextElementSibling;
                    }
                } else {
                    blocks.push({ language: languageOf(unit.node), code: unit.node.textContent });
                }
                return { key: unit.key, kind: unit.kind, heading: unit.heading, index: unit.index, tabbed: unit.tabbed, blocks };
            });
        }, LANGUAGES);
        if (units.length) pages[name.replace(/\.html$/, '')] = units;
        console.error(name + ': ' + units.length + ' code locations');
    }
    await browser.close();
    return pages;
}

async function main() {
    const pages = await crawl();
    const total = Object.values(pages).reduce((n, u) => n + u.length, 0);
    console.log('crawled ' + Object.keys(pages).length + ' pages, ' + total + ' code locations');
    const drift = markupDrift.slice();
    const names = Object.keys(pages).sort();
    for (const name of names) {
        const file = path.join(CATALOG, name + '.md');
        const content = render(name, pages[name]) + '\n';
        if (mode === 'update') {
            fs.writeFileSync(file, content);
        } else if (!fs.existsSync(file)) {
            drift.push(name + ': new page with ' + pages[name].length + ' code locations');
        } else if (fs.readFileSync(file, 'utf8') !== content) {
            const sectionsOf = text => {
                const map = new Map();
                for (const part of text.split(/^## /m).slice(1)) {
                    map.set(part.split('\n', 1)[0].trim(), part);
                }
                return map;
            };
            const before = sectionsOf(fs.readFileSync(file, 'utf8'));
            const after = sectionsOf(content);
            for (const k of before.keys()) if (!after.has(k)) drift.push(name + ': entry removed "' + k + '"');
            for (const k of after.keys()) {
                if (!before.has(k)) drift.push(name + ': entry added "' + k + '"');
                else if (before.get(k) !== after.get(k)) drift.push(name + ': snippet changed under "' + k + '"');
            }
        }
    }
    if (mode === 'update') {
        for (const existing of fs.readdirSync(CATALOG)) {
            if (existing.endsWith('.md') && !pages[existing.slice(0, -3)]) {
                fs.unlinkSync(path.join(CATALOG, existing));
                console.log('removed ' + existing + ' (page gone)');
            }
        }
        console.log('wrote ' + names.length + ' files under extension/catalog/');
        for (const line of markupDrift) console.log('  markup: ' + line);
        if (markupDrift.length) {
            console.log('The extension keys off that markup. Check extension/keys.js, content.js, and content.css.');
        }
        return;
    }
    for (const existing of fs.readdirSync(CATALOG)) {
        if (existing.endsWith('.md') && !pages[existing.slice(0, -3)]) drift.push(existing.slice(0, -3) + ': page gone');
    }
    if (!drift.length) {
        console.log('catalog: fmod.com matches extension/catalog/');
        return;
    }
    console.log('catalog: fmod.com changed in ' + drift.length + ' place(s):');
    for (const line of drift) console.log('  ' + line);
    console.log('Run node extension/test/catalog-site.js --update, then bring extension/haxe/ in line.');
    if (markupDrift.length) {
        console.log('A "markup" line above is a renamed element, not a snippet edit. Fix extension/keys.js, content.js, or content.css for it.');
    }
    process.exit(1);
}

main().catch(e => { console.error(e.stack || String(e)); process.exit(1); });
