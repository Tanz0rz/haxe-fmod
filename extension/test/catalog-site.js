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
// Needs the playwright package on NODE_PATH. Runs headless, no extension
// involved. Set CHROMIUM_PATH to use a system Chromium.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE = 'https://www.fmod.com/docs/2.03/api/';
const CATALOG = path.join(__dirname, '..', 'catalog');
const KEYS = path.join(__dirname, '..', 'keys.js');
const mode = process.argv.includes('--update') ? 'update' : process.argv.includes('--check') ? 'check' : null;
if (!mode) {
    console.error('usage: node extension/test/catalog-site.js --update | --check');
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

async function crawl() {
    const launch = { args: ['--no-sandbox'] };
    if (process.env.CHROMIUM_PATH) launch.executablePath = process.env.CHROMIUM_PATH;
    const browser = await chromium.launch(launch);
    const page = await browser.newPage();
    const keysSource = fs.readFileSync(KEYS, 'utf8');
    const queue = ['welcome.html'];
    const seen = new Set(queue);
    const pages = {};
    while (queue.length) {
        const name = queue.shift();
        try {
            await page.goto(BASE + name, { waitUntil: 'networkidle', timeout: 60000 });
            await page.waitForSelector('div.manual-content', { timeout: 30000 });
        } catch (e) {
            console.error('skip ' + name + ': ' + e.message.split('\n')[0]);
            continue;
        }
        const links = await page.evaluate(() => Array.from(document.querySelectorAll('a[href]'))
            .map(a => a.getAttribute('href'))
            .filter(h => h && /^[a-z0-9-]+\.html/.test(h))
            .map(h => h.split('#')[0]));
        for (const link of links) if (!seen.has(link)) { seen.add(link); queue.push(link); }

        await page.evaluate(keysSource);
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
                return { key: unit.key, kind: unit.kind, heading: unit.heading, index: unit.index, blocks };
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
    const drift = [];
    const names = Object.keys(pages).sort();
    for (const name of names) {
        const file = path.join(CATALOG, name + '.md');
        const content = render(name, pages[name]) + '\n';
        if (mode === 'update') {
            fs.writeFileSync(file, content);
        } else if (!fs.existsSync(file)) {
            drift.push(name + ': new page with ' + pages[name].length + ' code locations');
        } else if (fs.readFileSync(file, 'utf8') !== content) {
            const before = new Set(fs.readFileSync(file, 'utf8').split('\n').filter(l => l.startsWith('## ')));
            const after = new Set(content.split('\n').filter(l => l.startsWith('## ')));
            for (const k of before) if (!after.has(k)) drift.push(name + ': entry removed ' + k.slice(3));
            for (const k of after) if (!before.has(k)) drift.push(name + ': entry added ' + k.slice(3));
            if ([...before].every(k => after.has(k)) && [...after].every(k => before.has(k))) drift.push(name + ': snippet text changed');
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
    process.exit(1);
}

main().catch(e => { console.error(e.stack || String(e)); process.exit(1); });
