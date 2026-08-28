// Loads the unpacked extension into Chromium and drives the fixture page
// (served in place of fmod.com) through the tab flow: the Haxe tab exists
// on every function, selecting it shows the Haxe block and hides the
// others, picking C++ again hides it, and the choice survives a reload.
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
const URL = 'https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html';
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
        await context.route('https://www.fmod.com/**', route => route.fulfill({ status: 200, contentType: 'text/html', body: html }));
    }
    const page = await context.newPage();
    page.on('pageerror', e => fail('page error: ' + e.message));

    await page.goto(URL, { waitUntil: 'load' });
    await page.waitForSelector('.haxefmod-tab', { timeout: 30000 });

    const counts = await page.evaluate(() => ({
        functions: document.querySelectorAll('div.manual-content.api h2[api="function"]').length,
        tabs: document.querySelectorAll('.haxefmod-tab').length,
        blocks: document.querySelectorAll('.haxefmod-block').length,
    }));
    console.log('functions ' + counts.functions + ', haxe tabs ' + counts.tabs + ', haxe blocks ' + counts.blocks);
    if (counts.tabs !== counts.functions || counts.blocks !== counts.functions) fail('every function needs one Haxe tab and block');

    const startBlock = () => page.evaluate(() => {
        const heading = document.getElementById('studio_eventinstance_start');
        let node = heading.nextElementSibling;
        while (node && !node.classList.contains('haxefmod-block')) node = node.nextElementSibling;
        return { text: node.textContent, display: node.style.display };
    });

    let start = await startBlock();
    if (start.display !== 'none') fail('Haxe block visible before selection');
    if (start.text.indexOf('eventInstance.start():FmodResult') < 0) fail('start block lacks the Haxe signature: ' + start.text);

    await page.click('#studio_eventinstance_start ~ .language-selector .haxefmod-tab');
    await page.waitForTimeout(150);
    start = await startBlock();
    if (start.display !== 'block') fail('Haxe block hidden after selecting the tab');
    const cppVisible = await page.evaluate(() => Array.from(document.querySelectorAll('.language-cpp')).some(n => n.style.display !== 'none'));
    if (cppVisible) fail('C++ blocks still visible with Haxe selected');
    const selectedHaxe = await page.evaluate(() => document.querySelectorAll('.haxefmod-tab.selected').length);
    if (selectedHaxe !== counts.functions) fail('every Haxe tab should be selected, got ' + selectedHaxe);
    const storedValue = await page.evaluate(() => localStorage.getItem('FMOD.Documents.selected-language'));
    if (storedValue !== 'language-haxe') fail('selection not stored, got ' + storedValue);

    if (!live) {
        const unbound = await page.evaluate(() => {
            const heading = document.getElementById('studio_system_getadvancedsettings');
            let node = heading.nextElementSibling;
            while (node && !node.classList.contains('haxefmod-block')) node = node.nextElementSibling;
            return node.textContent;
        });
        if (unbound.indexOf('Not exposed by haxefmod') < 0) fail('unbound function lacks the not-exposed note');
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

    await page.screenshot({ path: path.join(__dirname, 'last-run.png'), fullPage: true });
    await context.close();
    console.log('extension test passed' + (live ? ' (live fmod.com)' : ' (fixture)'));
}

main().catch(e => fail(e.stack || String(e)));
