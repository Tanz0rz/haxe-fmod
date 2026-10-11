// Loads each playable example game from a built games directory in
// headless chromium with the default autoplay policy, the way a visitor
// sees it. Fails unless the music starts, audio stays locked until the
// first click on the game, that click unlocks FMOD's audio, and space plays
// the jump sound once the player lands. Each game must also freeze while
// its frame is out of focus and move again once it is back, checked from a
// host page that frames the game the way the docs site does. In that frame
// it must also start paused until the first click. While paused it must
// show flixel's pause screen, the game darkened by half under a
// white play arrow. Any page
// error or failed request fails the game too.
// Usage: node ci/check-example-games.js <games dir>
const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require('playwright');

const GAMES = ['haxeflixel', 'heaps', 'kha'];
const UNLOCKED = 'Resetting audio driver based on user input.';
const STARTED = 'FMOD: PlaySong event:/Music/MainLevel';
const EXPECTED = [STARTED, UNLOCKED, 'FMOD: PlayOneShot event:/SFX/Jump'];
const TYPES = {
  '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.png': 'image/png', '.ico': 'image/x-icon',
};

const root = path.resolve(process.argv[2] || '');
if (!process.argv[2] || !fs.existsSync(root)) {
  console.error('usage: node ci/check-example-games.js <games dir>');
  process.exit(2);
}

// A page that frames one game and holds a button to take focus away from it
const HOST = '<!doctype html><body style="margin:0"><button id="away" style="display:block;height:20px">away</button>' +
  '<iframe id="game" style="display:block;width:640px;height:480px;border:0"></iframe></body>';

const server = http.createServer((req, res) => {
  if (req.url === '/__host.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(HOST);
    return;
  }
  let file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(root)) { res.writeHead(403); res.end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

// True when the framed game draws a different picture after ms, with key
// held down for that time when one is given
async function changes(page, ms, key) {
  const frame = page.locator('#game');
  const before = await frame.screenshot();
  if (key) await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  if (key) await page.keyboard.up(key);
  return !before.equals(await frame.screenshot());
}

// The brightness, 0 to 255, of every pixel in each region of a screenshot.
// A region is [x, y, width, height] as fractions of the picture's size.
async function brightness(page, png, regions) {
  return page.evaluate(async ({ data, regions }) => {
    const img = new Image();
    img.src = `data:image/png;base64,${data}`;
    await img.decode();
    const canvas = document.createElement('canvas');
    canvas.width = img.width;
    canvas.height = img.height;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0);
    return regions.map(([x, y, w, h]) => {
      const d = ctx.getImageData(Math.round(x * img.width), Math.round(y * img.height),
        Math.round(w * img.width), Math.round(h * img.height)).data;
      const values = [];
      for (let i = 0; i < d.length; i += 4) values.push((d[i] + d[i + 1] + d[i + 2]) / 3);
      return values;
    });
  }, { data: png.toString('base64'), regions });
}

const mean = values => values.reduce((a, b) => a + b, 0) / values.length;

// A strip at the left edge, clear of the arrow and of the player's path
const EDGE = [0.02, 0.4, 0.13, 0.4];
// A box inside the pause arrow
const ARROW = [0.4, 0.48, 0.1, 0.04];

// Resolves once a console line contains text, throws after ms
async function waitForLog(logs, text, ms) {
  const deadline = Date.now() + ms;
  while (!logs.some(l => l.includes(text))) {
    if (Date.now() > deadline) throw new Error(`never logged "${text}"`);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
}

async function checkPause(browser, base, game) {
  const problems = [];
  const page = await browser.newPage({ viewport: { width: 700, height: 560 } });
  const logs = [];
  page.on('console', m => logs.push(m.text()));
  try {
    await page.goto(`${base}/__host.html`);
    await page.evaluate(src => { document.getElementById('game').src = src; }, `/${game}/`);
    await waitForLog(logs, STARTED, 25000);
    // A framed game starts out of focus, frozen behind the pause screen
    await page.waitForTimeout(500);
    const [startEdge, startArrow] = await brightness(page, await page.locator('#game').screenshot(), [EDGE, ARROW]);
    if (await changes(page, 1000)) problems.push('ran before the first click');
    // The player drops from the top right after the first click, so a
    // running game changes its picture while the frame is out of focus
    await page.locator('#game').click({ position: { x: 320, y: 240 } });
    await page.waitForTimeout(300);
    const [edge] = await brightness(page, await page.locator('#game').screenshot(), [EDGE]);
    const unlit = startEdge.filter((v, i) => v > edge[i] * 0.65 + 4).length / edge.length;
    if (unlit > 0.01 || mean(startArrow) < Math.max(150, mean(startEdge) * 1.8)) {
      problems.push(`no pause screen before the first click (edge brightness ${mean(startEdge).toFixed(0)} then ${mean(edge).toFixed(0)}, arrow ${mean(startArrow).toFixed(0)})`);
    }
    await page.click('#away');
    await page.waitForTimeout(300);
    const [pausedEdge, pausedArrow] = await brightness(page, await page.locator('#game').screenshot(), [EDGE, ARROW]);
    // Every pixel darkens, so tiles, coins or text drawn over the pause
    // screen fail it too
    const lit = pausedEdge.filter((v, i) => v > edge[i] * 0.65 + 4).length / edge.length;
    if (lit > 0.01) {
      problems.push(`${(lit * 100).toFixed(0)}% of the edge strip did not darken (brightness ${mean(edge).toFixed(0)} then ${mean(pausedEdge).toFixed(0)})`);
    }
    if (mean(pausedArrow) < Math.max(150, mean(pausedEdge) * 1.8)) {
      problems.push(`no pause arrow (arrow brightness ${mean(pausedArrow).toFixed(0)}, edge ${mean(pausedEdge).toFixed(0)})`);
    }
    if (await changes(page, 1200)) problems.push('kept running with its frame out of focus');
    await page.locator('#game').click({ position: { x: 320, y: 240 } });
    if (!await changes(page, 800, 'ArrowRight')) problems.push('did not move after it got focus back');
    const [backEdge] = await brightness(page, await page.locator('#game').screenshot(), [EDGE]);
    if (mean(backEdge) < mean(edge) * 0.85) {
      problems.push(`pause screen stayed up with focus back (edge brightness ${mean(edge).toFixed(0)} then ${mean(backEdge).toFixed(0)})`);
    }
  } catch (e) {
    problems.push(`pause check: ${e.message.split('\n')[0]}`);
  }
  await page.close();
  return problems;
}

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  let failed = false;
  for (const game of GAMES) {
    const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
    const logs = [];
    const problems = [];
    page.on('console', m => logs.push(m.text()));
    page.on('pageerror', e => problems.push(`page error: ${e.message}`));
    page.on('requestfailed', r => problems.push(`request failed: ${r.url()}`));
    page.on('response', r => { if (r.status() >= 400) problems.push(`HTTP ${r.status()}: ${r.url()}`); });
    await page.goto(`${base}/${game}/`);
    try {
      await waitForLog(logs, STARTED, 25000);
      await page.waitForTimeout(500);
      if (logs.some(l => l.includes(UNLOCKED))) problems.push('audio started before the first click');
      await page.locator('canvas').first().click();
    } catch (e) {
      problems.push(`first click: ${e.message.split('\n')[0]}`);
    }
    // The player drops from the top of the level, then jumps
    await page.waitForTimeout(3000);
    // Held for a few frames, as a real key tap is. Flixel and Heaps read
    // a press per frame and miss one that ends inside the same frame
    await page.keyboard.down('Space');
    await page.waitForTimeout(150);
    await page.keyboard.up('Space');
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline && !EXPECTED.every(e => logs.some(l => l.includes(e)))) {
      await page.waitForTimeout(250);
    }
    for (const e of EXPECTED) {
      if (!logs.some(l => l.includes(e))) problems.push(`never logged "${e}"`);
    }
    await page.close();
    problems.push(...await checkPause(browser, base, game));
    if (problems.length) {
      failed = true;
      console.log(`FAIL: ${game}`);
      for (const p of problems) console.log(`  ${p}`);
      for (const l of logs.slice(-20)) console.log(`  log: ${l}`);
    } else {
      console.log(`ok: ${game} unlocked audio on the first click, played the music and the jump, started paused in a frame, and paused behind the pause screen out of focus`);
    }
  }
  await browser.close();
  server.close();
  process.exit(failed ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
