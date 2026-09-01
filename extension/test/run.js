// Loads the unpacked extension into Chromium and drives the fixture page
// (served in place of fmod.com) through the tab flow (the Haxe tab exists
// on every function, selecting it shows the Haxe block and hides the
// others, picking C++ again hides it, and the choice survives a reload),
// then a guide page whose lone C++ examples get a selector of their own.
//
// Usage: node extension/test/run.js [--live] [--all] [--headless]
// --live runs the same checks against the real fmod.com page instead of
// the fixture (needs network).
// --all also drives a fixture generated from every catalog page (see
// build-fixtures.js) and holds these invariants on each: one Haxe tab
// per unit, no tab strip left standing over blocks that are all hidden,
// selecting Haxe shows exactly one Haxe block per covered unit with one
// footer each, and re-rendering the page (the SPA way) adds nothing.
//
// Needs the playwright package on NODE_PATH and a display: extensions
// only load in headed Chromium, so run under xvfb-run on a headless
// box, or pass --headless to use Chromium's new headless mode, which
// loads extensions without a display.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');
const { buildAll, parseCatalog } = require('./build-fixtures');

const EXTENSION = path.resolve(__dirname, '..');
const FIXTURE = path.join(__dirname, 'fixture.html');
const GUIDE_FIXTURE = path.join(__dirname, 'fixture-guide.html');
const URL = 'https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html';
const GUIDE_URL = 'https://www.fmod.com/docs/2.03/api/studio-guide.html';
const EXAMPLES_DATA = path.join(__dirname, '..', 'examples-data.js');

// The translations the extension ships for one page, read the same way
// the content script does.
function examplesFor(page) {
    const source = fs.readFileSync(EXAMPLES_DATA, 'utf8');
    const json = source.slice(source.indexOf('{'), source.lastIndexOf('}') + 1);
    return JSON.parse(json)[page] || {};
}
const live = process.argv.includes('--live');
const all = process.argv.includes('--all');
const headless = process.argv.includes('--headless');

function fail(message) {
    console.error('FAIL: ' + message);
    process.exit(1);
}

async function main() {
    const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'haxefmod-ext-'));
    const launch = {
        headless: false,
        args: [
            '--no-sandbox',
            '--disable-extensions-except=' + EXTENSION,
            '--load-extension=' + EXTENSION,
        ],
    };
    if (headless) launch.args.push('--headless=new');
    if (process.env.CHROMIUM_PATH) launch.executablePath = process.env.CHROMIUM_PATH;
    const context = await chromium.launchPersistentContext(profile, launch);
    if (!live) {
        const html = fs.readFileSync(FIXTURE, 'utf8');
        const guideHtml = fs.readFileSync(GUIDE_FIXTURE, 'utf8');
        await context.route('https://www.fmod.com/**', route => route.fulfill({
            status: 200, contentType: 'text/html',
            body: route.request().url().indexOf('studio-guide') >= 0 ? guideHtml : html,
        }));
    }
    const page = await context.newPage();
    page.on('pageerror', e => fail('page error: ' + e.message));

    await page.goto(URL, { waitUntil: 'load' });
    await page.waitForSelector('.haxefmod-tab', { timeout: 30000 });

    // Function entries get a tab each. Example blocks on the same page
    // get one too when a translation exists, so they are counted apart.
    const counts = await page.evaluate(() => {
        const headings = Array.from(document.querySelectorAll('div.manual-content.api h2[api="function"]'));
        const functionTabs = headings.filter(h => {
            let node = h.nextElementSibling;
            for (let i = 0; node && i < 4; i++) {
                if (node.classList.contains('language-selector')) return node.querySelector('.haxefmod-tab') !== null;
                node = node.nextElementSibling;
            }
            return false;
        }).length;
        return {
            functions: headings.length,
            functionTabs,
            tabs: document.querySelectorAll('.haxefmod-tab').length,
            blocks: document.querySelectorAll('.haxefmod-block').length,
        };
    });
    console.log('functions ' + counts.functions + ' (' + counts.functionTabs + ' with a Haxe tab), haxe tabs ' + counts.tabs + ', haxe blocks ' + counts.blocks);
    if (counts.functionTabs !== counts.functions) fail('every function needs a Haxe tab');
    if (counts.blocks !== counts.tabs) fail('every Haxe tab needs a block');

    const startBlock = () => page.evaluate(() => {
        const heading = document.getElementById('studio_eventinstance_start');
        let node = heading.nextElementSibling;
        while (node && !node.classList.contains('haxefmod-block')) node = node.nextElementSibling;
        return { text: node.textContent, display: node.style.display };
    });

    let start = await startBlock();
    if (start.display !== 'none') fail('Haxe block visible before selection');
    if (start.text.indexOf('haxefmod.studio.EventInstance.start():FmodResult;') < 0) fail('start block lacks the Haxe signature: ' + start.text);

    await page.click('#studio_eventinstance_start ~ .language-selector .haxefmod-tab');
    await page.waitForTimeout(150);
    start = await startBlock();
    if (start.display !== 'block') fail('Haxe block hidden after selecting the tab');
    const cppVisible = await page.evaluate(() => Array.from(document.querySelectorAll('.language-cpp')).some(n => n.style.display !== 'none'));
    if (cppVisible) fail('C++ blocks still visible with Haxe selected');
    const selectedHaxe = await page.evaluate(() => document.querySelectorAll('.haxefmod-tab.selected').length);
    if (selectedHaxe !== counts.tabs) fail('every Haxe tab should be selected, got ' + selectedHaxe);
    const storedValue = await page.evaluate(() => localStorage.getItem('FMOD.Documents.selected-language'));
    if (storedValue !== 'language-haxe') fail('selection not stored, got ' + storedValue);

    if (!live) {
        const unbound = await page.evaluate(() => {
            const heading = document.getElementById('system_setfilesystem');
            let node = heading.nextElementSibling;
            while (node && !node.classList.contains('haxefmod-block')) node = node.nextElementSibling;
            return node.textContent;
        });
        if (unbound.indexOf('Cannot be bound') < 0) fail('an impossible function should say it cannot be bound: ' + unbound);
        const also = await page.evaluate(() => {
            const heading = document.getElementById('studio_eventinstance_set3dattributes');
            let node = heading.nextElementSibling;
            while (node && !node.classList.contains('haxefmod-block')) node = node.nextElementSibling;
            return node.textContent;
        });
        if (also.indexOf('setPosition2D') < 0) fail('set3DAttributes block should mention setPosition2D');
    }

    await page.reload({ waitUntil: 'load' });
    await page.waitForSelector('.haxefmod-tab', { timeout: 30000 });
    await page.waitForTimeout(300);
    start = await startBlock();
    if (start.display !== 'block') fail('Haxe selection did not survive a reload');

    // Swapping blocks must not move the tab under the pointer: scroll so
    // the last function's tab sits mid-viewport, click Haxe, and the tab
    // stays at the same viewport position although the block below it
    // changed height.
    const pinned = await page.evaluate(async () => {
        const selectors = document.querySelectorAll('h2[api="function"] ~ .language-selector');
        const selector = selectors[selectors.length - 1];
        const tab = selector.querySelector('.language-tab[data-language="language-haxe"]');
        tab.scrollIntoView({ block: 'center' });
        await new Promise(r => setTimeout(r, 100));
        const before = tab.getBoundingClientRect().top;
        tab.click();
        await new Promise(r => setTimeout(r, 200));
        return { before, after: tab.getBoundingClientRect().top };
    });
    if (Math.abs(pinned.after - pinned.before) > 1) fail('clicking a Haxe tab moved it from ' + pinned.before + ' to ' + pinned.after);
    await page.evaluate(() => window.scrollTo(0, 0));

    await page.click('#studio_eventinstance_start ~ .language-selector .language-tab[data-language="language-cpp"]');
    await page.waitForTimeout(150);
    start = await startBlock();
    if (start.display !== 'none') fail('Haxe block still visible after picking C++');
    const cppBack = await page.evaluate(() => Array.from(document.querySelectorAll('.language-cpp')).every(n => n.style.display !== 'none'));
    if (!cppBack) fail('C++ blocks did not come back');

    // Guide page: lone C++ blocks get a selector and a Haxe block for
    // every example the translations cover.
    const examples = examplesFor('studio-guide');
    await page.goto(GUIDE_URL, { waitUntil: 'load' });
    await page.waitForSelector('div.manual-content div.highlight', { timeout: 30000 });
    await page.waitForTimeout(500);
    const guide = await page.evaluate(() => ({
        lone: document.querySelectorAll('div.manual-content div.highlight:not(.haxefmod-block)').length,
        selectors: document.querySelectorAll('.haxefmod-selector').length,
        tabs: document.querySelectorAll('.haxefmod-tab').length,
        blocks: document.querySelectorAll('.haxefmod-block').length,
    }));
    const covered = Object.keys(examples).length;
    console.log('guide: ' + guide.lone + ' lone blocks, ' + guide.selectors + ' added selectors, ' + guide.blocks + ' haxe blocks, ' + covered + ' translations');
    if (guide.blocks !== covered || guide.tabs !== covered) fail('guide page should get one Haxe block per translated example');
    if (covered > 0) {
        const first = await page.evaluate(() => {
            const block = document.querySelector('.haxefmod-block');
            return { text: block.textContent, display: block.style.display };
        });
        if (first.display !== 'none') fail('guide Haxe block visible before selection');
        await page.click('.haxefmod-tab');
        await page.waitForTimeout(150);
        const after = await page.evaluate(() => ({
            haxe: Array.from(document.querySelectorAll('.haxefmod-block')).every(n => n.style.display === 'block'),
            cpp: Array.from(document.querySelectorAll('div.highlight.language-cpp:not(.haxefmod-block)')).every(n => n.style.display === 'none'),
        }));
        if (!after.haxe || !after.cpp) fail('selecting Haxe on a guide page should show every Haxe block and hide the C++ ones');
        await page.click('.haxefmod-selector .language-tab[data-language="language-cpp"]');
        await page.waitForTimeout(150);
        const back = await page.evaluate(() => ({
            haxe: Array.from(document.querySelectorAll('.haxefmod-block')).every(n => n.style.display === 'none'),
            cpp: Array.from(document.querySelectorAll('div.highlight.language-cpp:not(.haxefmod-block)')).every(n => n.style.display === 'block'),
        }));
        if (!back.haxe || !back.cpp) fail('picking C++ on an added selector should restore the C++ blocks');
    }

    // The matrix: a fixture built from every catalog page, so every DOM
    // shape the site has (tabbed functions, tabbed examples, lone
    // blocks, per-language runs, plain blocks) is driven with the same
    // invariants.
    if (all && !live) {
        const fixtures = buildAll();
        await context.unroute('https://www.fmod.com/**');
        await context.route('https://www.fmod.com/**', route => {
            const name = route.request().url().split('/').pop().split('#')[0].replace('.html', '');
            if (fixtures[name]) route.fulfill({ status: 200, contentType: 'text/html', body: fixtures[name] });
            else route.fulfill({ status: 404, contentType: 'text/html', body: 'no fixture' });
        });
        let unitsChecked = 0;
        for (const name of Object.keys(fixtures)) {
            const examples = examplesFor(name);
            // A unit under the site's own selector (a function, a tabbed
            // example) carries a Haxe tab. A lone unit on a page that
            // has any site selector only gets the Haxe block, the
            // page's own tabs govern it. Only a page with no selector
            // at all gets a strip per covered lone unit.
            const entries = parseCatalog(fs.readFileSync(path.join(__dirname, '..', 'catalog', name + '.md'), 'utf8'));
            const functions = entries.filter(e => e.kind === 'function').length;
            const hasSelector = entries.some(e => e.kind === 'function' || e.tabbed);
            const byKey = new Map(entries.map(e => [e.key, e]));
            let tabbedCovered = 0;
            let loneCovered = 0;
            for (const key of Object.keys(examples)) {
                const entry = byKey.get(key);
                if (entry && entry.tabbed) tabbedCovered++;
                else loneCovered++;
            }
            const expected = functions + tabbedCovered + loneCovered;
            const expectedTabs = functions + tabbedCovered + (hasSelector ? 0 : loneCovered);
            const expectedStrips = hasSelector ? 0 : loneCovered;

            await page.evaluate(() => { try { localStorage.clear(); } catch (e) { } });
            await page.goto('https://www.fmod.com/docs/2.03/api/' + name + '.html', { waitUntil: 'load' });
            await page.waitForFunction(() => document.querySelectorAll('div.manual-content div.highlight').length > 0, null, { timeout: 30000 });
            await page.waitForTimeout(300);

            const counts = await page.evaluate(() => ({
                tabs: document.querySelectorAll('.haxefmod-tab').length,
                blocks: document.querySelectorAll('.haxefmod-block').length,
                strips: document.querySelectorAll('.haxefmod-selector').length,
                footers: Array.from(document.querySelectorAll('.haxefmod-block')).filter(b => b.querySelectorAll('.haxefmod-footer').length === 1).length,
            }));
            if (counts.tabs !== expectedTabs) fail(name + ': ' + counts.tabs + ' Haxe tabs, expected ' + expectedTabs + ' (' + functions + ' functions, ' + tabbedCovered + ' tabbed, ' + loneCovered + ' lone)');
            if (counts.blocks !== expected) fail(name + ': ' + counts.blocks + ' Haxe blocks, expected ' + expected);
            if (counts.strips !== expectedStrips) fail(name + ': ' + counts.strips + ' added strips, expected ' + expectedStrips + (hasSelector ? ' (the site selector governs this page)' : ''));
            if (counts.footers !== counts.blocks) fail(name + ': every Haxe block carries one footer, ' + counts.footers + ' of ' + counts.blocks + ' do');

            // No tab strip may stand over blocks that are all hidden,
            // whatever language is picked. Click through every tab
            // language the page offers, Haxe included.
            const langs = await page.evaluate(() => Array.from(new Set(
                Array.from(document.querySelectorAll('.language-tab')).map(t => t.getAttribute('data-language'))
            )));
            for (const lang of langs) {
                const tab = page.locator('.language-tab[data-language="' + lang + '"]:visible').first();
                if (await tab.count() === 0) continue;
                await tab.click();
                await page.waitForTimeout(120);
                const state = await page.evaluate(() => {
                    // The site's own selectors can stand over blocks it
                    // hid itself (a unit without the picked language),
                    // with or without this extension. The invariant is
                    // for the strips the extension added.
                    const orphans = [];
                    for (const strip of document.querySelectorAll('div.manual-content div.haxefmod-selector')) {
                        if (getComputedStyle(strip).display === 'none') continue;
                        let node = strip.nextElementSibling;
                        let visible = 0;
                        while (node && (node.classList.contains('highlight') || (node.tagName === 'P' && node.textContent.trim() === ''))) {
                            if (node.classList.contains('highlight') && getComputedStyle(node).display !== 'none') visible++;
                            node = node.nextElementSibling;
                        }
                        if (!visible) orphans.push(strip.textContent.replace(/\s+/g, ' ').trim());
                    }
                    const haxeVisible = Array.from(document.querySelectorAll('.haxefmod-block')).filter(b => b.style.display !== 'none').length;
                    return { orphans, haxeVisible };
                });
                if (state.orphans.length) fail(name + ': tab strips with every block hidden after picking ' + lang + ': ' + state.orphans.slice(0, 3).join(' | '));
                if (lang === 'language-haxe' && state.haxeVisible !== expected) fail(name + ': ' + state.haxeVisible + ' Haxe blocks visible with Haxe picked, expected ' + expected);
                if (lang !== 'language-haxe' && lang !== 'language-all' && state.haxeVisible !== 0) fail(name + ': Haxe blocks still visible after picking ' + lang);
            }

            // A re-render of the same content (the SPA way) must add
            // nothing: same tabs, same blocks.
            await page.evaluate(() => window.__rerender());
            await page.waitForTimeout(300);
            const again = await page.evaluate(() => ({
                tabs: document.querySelectorAll('.haxefmod-tab').length,
                blocks: document.querySelectorAll('.haxefmod-block').length,
            }));
            if (again.tabs !== expectedTabs || again.blocks !== expected) fail(name + ': re-render changed the page, ' + again.tabs + ' tabs and ' + again.blocks + ' blocks for ' + expectedTabs + ' and ' + expected);
            unitsChecked += expected;
        }
        console.log('matrix: ' + Object.keys(fixtures).length + ' pages, ' + unitsChecked + ' units held the invariants');
    }

    await page.screenshot({ path: path.join(__dirname, 'last-run.png'), fullPage: true });
    await context.close();
    console.log('extension test passed' + (live ? ' (live fmod.com)' : ' (fixture)'));
}

main().catch(e => fail(e.stack || String(e)));
