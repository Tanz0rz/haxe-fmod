// Runs one html5 test state in Firefox through Playwright and gates on
// its console output, mirroring the chromium browser steps. Firefox is
// the second engine for the log-gated states: the FMOD JS glue defects
// all surfaced on V8 first, and this job gives SpiderMonkey the same
// chance to disagree.
//
// Usage: node ci/run-firefox-state.js <url> <gate> <log-file> [timeout-s]
// Requires the playwright package (resolve via NODE_PATH) with its
// Firefox build installed. Runs headed, so a DISPLAY must exist.
const fs = require('fs');
const { firefox } = require('playwright');

const [url, gate, logFile, timeoutArg] = process.argv.slice(2);
if (!url || !gate || !logFile) {
    console.error('usage: node ci/run-firefox-state.js <url> <gate> <log-file> [timeout-s]');
    process.exit(2);
}
const timeoutMs = (parseInt(timeoutArg, 10) || 120) * 1000;

async function main() {
    const browser = await firefox.launch({
        headless: false,
        firefoxUserPrefs: {
            'media.autoplay.default': 0,
            'media.autoplay.blocking_policy': 0,
            'media.autoplay.block-webaudio': false,
        },
    });
    const page = await browser.newPage({ viewport: { width: 640, height: 480 } });
    const lines = [];
    const allMessages = [];
    let done = false;
    page.on('console', msg => {
        const text = msg.text();
        if (allMessages.length < 2000) allMessages.push(text);
        if (text.startsWith(gate + ':')) {
            lines.push(text);
            console.log(text);
            if (text.startsWith(gate + ': COMPLETE')) done = true;
        }
    });
    page.on('pageerror', err => {
        lines.push(gate + ': PAGEERROR ' + String(err).slice(0, 200));
        console.log(lines[lines.length - 1]);
    });
    page.on('crash', () => {
        lines.push(gate + ': PAGEERROR page crashed');
        console.log(lines[lines.length - 1]);
    });

    await page.goto(url);
    // jaxe installs its audio resume handler when the FMOD module
    // finishes its async init, so the activation click has to land after
    // that. Firefox keeps the AudioContext suspended until a real
    // gesture reaches the handler (the chromium steps sidestep this with
    // the autoplay flag).
    let initSeen = true;
    // jaxe is a top-level class declaration, so it is a bare global and
    // never lands on window
    await page.waitForFunction("typeof jaxe !== 'undefined' && jaxe.FmodIsInitialized === true",
        null, { timeout: 60000 }).catch(() => { initSeen = false; });
    console.log(`runner: init wait ${initSeen ? 'resolved' : 'TIMED OUT after 60s'}`);
    await page.mouse.click(320, 240);
    await new Promise(r => setTimeout(r, 1000));
    await page.mouse.click(320, 240);

    const start = Date.now();
    while (!done && Date.now() - start < timeoutMs) {
        await new Promise(r => setTimeout(r, 500));
    }

    // Diagnostics for runs that never produce gate lines
    const pageState = await page.evaluate(`({
        jaxe: typeof jaxe,
        init: typeof jaxe !== 'undefined' && !!jaxe.FmodIsInitialized,
        resumed: typeof jaxe !== 'undefined' && !!jaxe.gAudioResumed,
    })`).catch(e => ({ evalError: String(e).slice(0, 120) }));
    console.log('runner: page state ' + JSON.stringify(pageState));
    console.log(`runner: captured ${allMessages.length} console messages, ${lines.length} gate messages`);
    if (lines.length === 0 && allMessages.length > 0) {
        console.log('runner: first console messages:');
        for (const m of allMessages.slice(0, 10)) console.log('  | ' + m.slice(0, 160));
    }
    await browser.close();

    fs.writeFileSync(logFile, lines.join('\n') + '\n');
    if (!done) {
        console.error(`FAIL: ${gate} never reached COMPLETE in Firefox`);
        process.exit(1);
    }
    if (lines.some(l => l.includes('pass=false')) || lines.some(l => l.includes('PAGEERROR'))) {
        console.error(`FAIL: ${gate} reported failing checks in Firefox`);
        process.exit(1);
    }
    console.log(`${gate} passed in Firefox`);
}

main().catch(e => {
    console.error('FATAL', (e && e.message) || e);
    process.exit(1);
});
