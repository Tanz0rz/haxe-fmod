// Records what the extension depends on at fmod.com and reports drift.
//
// The Haxe tab is keyed by two things on the docs site: the id of every
// function heading, and the position of every code example on a page.
// FMOD editing a page can add or rename a function, or insert an example
// and shift the ones after it. This crawler walks every page of the API
// reference (following links from welcome.html) and writes a snapshot of
// those keys, one entry per page: the function ids in order, and every
// example unit with its kind, heading, and a hash of its C++ source.
//
// Usage: node extension/test/crawl-site.js --update   rewrite the snapshot
//        node extension/test/crawl-site.js --check    diff the live site
//                                                     against the snapshot
//                                                     and exit 1 on drift
//
// Needs the playwright package on NODE_PATH. Runs headless, no extension
// involved. Set CHROMIUM_PATH to use a system Chromium.
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE = 'https://www.fmod.com/docs/2.03/api/';
const SNAPSHOT = path.join(__dirname, 'site-snapshot.json');
const mode = process.argv.includes('--update') ? 'update' : process.argv.includes('--check') ? 'check' : null;
if (!mode) {
    console.error('usage: node extension/test/crawl-site.js --update | --check');
    process.exit(2);
}

function hash(text) {
    return crypto.createHash('sha1').update(text.replace(/\s+/g, ' ').trim()).digest('hex').slice(0, 12);
}

async function crawl() {
    const launch = { args: ['--no-sandbox'] };
    if (process.env.CHROMIUM_PATH) launch.executablePath = process.env.CHROMIUM_PATH;
    const browser = await chromium.launch(launch);
    const page = await browser.newPage();
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

        const data = await page.evaluate(() => {
            const root = document.querySelector('div.manual-content');
            const functions = Array.from(root.querySelectorAll('h2[api="function"]')).map(h => h.id);
            const nodes = Array.from(root.querySelectorAll('div.language-selector, div.highlight'));
            const attached = (hl) => {
                let n = hl.previousElementSibling;
                while (n && (n.classList.contains('highlight') || (n.tagName === 'P' && n.textContent.trim() === ''))) n = n.previousElementSibling;
                return !!(n && n.classList.contains('language-selector'));
            };
            const units = nodes.filter(n => n.classList.contains('language-selector') || !attached(n));
            const examples = [];
            units.forEach((unit, index) => {
                const tabbed = unit.classList.contains('language-selector');
                let node = unit.previousElementSibling;
                let isFunction = false;
                for (let i = 0; node && i < 4; i++) {
                    if (node.tagName === 'H2' && node.getAttribute('api') === 'function') { isFunction = true; break; }
                    node = node.previousElementSibling;
                }
                if (isFunction) return;
                let h = unit.previousElementSibling;
                while (h && !/^H[1-6]$/.test(h.tagName)) h = h.previousElementSibling;
                let code = '';
                if (tabbed) {
                    // The C++ block, or the block the site shares between C
                    // and C++ (language-c-cpp), or the C block as a last
                    // resort on C-only pages.
                    let n = unit.nextElementSibling;
                    let cCode = '';
                    while (n && (n.classList.contains('highlight') || (n.tagName === 'P' && n.textContent.trim() === ''))) {
                        if (n.classList.contains('language-cpp') || n.classList.contains('language-c-cpp')) code = n.textContent;
                        else if (n.classList.contains('language-c')) cCode = n.textContent;
                        n = n.nextElementSibling;
                    }
                    if (!code) code = cCode;
                } else {
                    code = unit.textContent;
                }
                // A type definition (struct, enum, define, callback typedef)
                // is recorded by its first line so the examples check can
                // require a matching Haxe declaration for it.
                const first = code.trim().split('\n')[0].trim();
                const decl = /^(typedef\s+(struct|enum)|enum\s|struct\s|#define\s|typedef\s+\w[\w\s*]*\(|FMOD_RESULT\s+\(F_CALL)/.test(first) ? first.slice(0, 80) : '';
                // The facts of the snippet the Haxe side is checked against:
                // the members a type declares, or the API calls an example
                // makes (Object::method, object->method, object.method).
                let members = [];
                let calls = [];
                if (decl) {
                    const body = code.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
                    if (/^(typedef\s+struct|struct\s)/.test(first)) {
                        members = Array.from(body.matchAll(/\b([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*;/g)).map(m => m[1]);
                    } else {
                        members = Array.from(body.matchAll(/\b((?:FMOD|FSBANK)_[A-Z0-9_]+)\b/g)).map(m => m[1]);
                        members = members.filter((m, i) => members.indexOf(m) === i && !first.includes(m));
                    }
                } else {
                    const body = code.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
                    calls = Array.from(body.matchAll(/(?:::|->|\.)\s*([a-z]\w*)\s*\(/g)).map(m => m[1]);
                    calls = calls.filter((c, i) => calls.indexOf(c) === i);
                }
                examples.push({ index, kind: tabbed ? 'tabbed' : 'lone', heading: h ? h.textContent.trim() : '', code, decl, members, calls });
            });
            return { functions, examples };
        });
        data.examples = data.examples.map(e => ({ index: e.index, kind: e.kind, heading: e.heading, code: hash(e.code), decl: e.decl, members: e.members, calls: e.calls }));
        if (data.functions.length || data.examples.length) pages[name.replace(/\.html$/, '')] = data;
        console.error(name + ': ' + data.functions.length + ' functions, ' + data.examples.length + ' examples');
    }
    await browser.close();
    return pages;
}

function diff(before, after) {
    const lines = [];
    const names = new Set([...Object.keys(before), ...Object.keys(after)]);
    for (const name of Array.from(names).sort()) {
        const a = before[name];
        const b = after[name];
        if (!a) { lines.push(name + ': new page with ' + b.functions.length + ' functions and ' + b.examples.length + ' examples'); continue; }
        if (!b) { lines.push(name + ': page gone'); continue; }
        const oldIds = new Set(a.functions);
        const newIds = new Set(b.functions);
        for (const id of a.functions) if (!newIds.has(id)) lines.push(name + ': function removed ' + id);
        for (const id of b.functions) if (!oldIds.has(id)) lines.push(name + ': function added ' + id);
        const count = Math.max(a.examples.length, b.examples.length);
        for (let i = 0; i < count; i++) {
            const x = a.examples[i];
            const y = b.examples[i];
            if (!x) { lines.push(name + ': example added at index ' + y.index + ' (' + y.heading + ')'); continue; }
            if (!y) { lines.push(name + ': example removed at index ' + x.index + ' (' + x.heading + ')'); continue; }
            if (x.index !== y.index) lines.push(name + ': example under "' + x.heading + '" moved from index ' + x.index + ' to ' + y.index);
            else if (x.heading !== y.heading) lines.push(name + ': example at index ' + x.index + ' now sits under "' + y.heading + '" (was "' + x.heading + '")');
            else if (x.code !== y.code) lines.push(name + ': example at index ' + x.index + ' (' + x.heading + ') changed its C++ source');
            else if (x.kind !== y.kind) lines.push(name + ': example at index ' + x.index + ' changed from ' + x.kind + ' to ' + y.kind);
        }
    }
    return lines;
}

async function main() {
    const pages = await crawl();
    const functions = Object.values(pages).reduce((n, p) => n + p.functions.length, 0);
    const examples = Object.values(pages).reduce((n, p) => n + p.examples.length, 0);
    console.log('crawled ' + Object.keys(pages).length + ' pages, ' + functions + ' functions, ' + examples + ' examples');
    if (mode === 'update') {
        fs.writeFileSync(SNAPSHOT, JSON.stringify(pages, null, 1) + '\n');
        console.log('wrote ' + path.relative(process.cwd(), SNAPSHOT));
        return;
    }
    const before = JSON.parse(fs.readFileSync(SNAPSHOT, 'utf8'));
    const lines = diff(before, pages);
    if (!lines.length) {
        console.log('site-snapshot: fmod.com matches the snapshot');
        return;
    }
    console.log('site-snapshot: fmod.com changed in ' + lines.length + ' place(s):');
    for (const line of lines) console.log('  ' + line);
    console.log('Update extension/examples and extension/functions.md as needed, then run with --update.');
    process.exit(1);
}

main().catch(e => { console.error(e.stack || String(e)); process.exit(1); });
