// Loads the unpacked extension into Chromium and drives the fixture page
// (served in place of fmod.com) through the tab flow (the Haxe tab exists
// on every function, selecting it shows the Haxe block and hides the
// others, picking C++ again hides it, and the choice survives a reload),
// then a guide page whose lone C++ examples get a selector of their own.
//
// Usage: node extension/test/run.js [--live]
// --live runs the same checks against the real fmod.com page instead of
// the fixture (needs network).
//
// Needs the playwright package on NODE_PATH and a display: extensions
// only load in headed Chromium, so run under xvfb-run on a headless box.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');

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
    if (start.text.indexOf('EventInstance.start():FmodResult;') < 0) fail('start block lacks the Haxe signature: ' + start.text);

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
    const covered = examples['*'] ? guide.lone : Object.keys(examples).length;
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

    await page.screenshot({ path: path.join(__dirname, 'last-run.png'), fullPage: true });
    await context.close();
    console.log('extension test passed' + (live ? ' (live fmod.com)' : ' (fixture)'));
}

main().catch(e => fail(e.stack || String(e)));
