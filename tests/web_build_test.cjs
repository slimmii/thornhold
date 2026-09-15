/* Browser smoke check against the actual release files. Requires Playwright. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const root = path.resolve(__dirname, '..');
const directory = path.join(root, 'builds/web');
const screenshots = path.join(root, 'screenshots');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const file = path.resolve(directory, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(directory + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    res.writeHead(404); res.end(); return;
  }
  res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
  res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
  fs.createReadStream(file).pipe(res);
});

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const errors = [];
  const messages = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', msg => {
      messages.push(`${msg.type()}: ${msg.text()}`);
      console.log(`${msg.type()}: ${msg.text()}`);
      if (msg.type() === 'error' && !msg.text().includes('favicon.ico')) errors.push(msg.text());
    });
    page.on('requestfailed', request => errors.push(`Failed request: ${request.url()} ${request.failure()?.errorText}`));
    await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 });
    await page.waitForFunction(() => !document.querySelector('#status'), null, { timeout: 120000 });
    await page.waitForTimeout(1500);
    assert.equal(await page.title(), 'Thornhold — The Emerald Gate');
    assert.equal(await page.evaluate(() => crossOriginIsolated), false, 'single-threaded release works without isolation headers');
    assert.equal((await page.request.get(url + '/index.wasm')).headers()['content-type'], 'application/wasm');
    await page.screenshot({ path: path.join(screenshots, 'web-title.png') });
    await page.mouse.click(220, 575);
    await page.waitForFunction(() => document.pointerLockElement?.id === 'canvas', null, { timeout: 10000 });
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(screenshots, 'web-gameplay.png') });
    await page.keyboard.down('w');
    await page.waitForTimeout(1600);
    await page.keyboard.up('w');
    await page.keyboard.press('b');
    await page.waitForFunction(() => document.pointerLockElement === null, null, { timeout: 10000 });
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(screenshots, 'web-armory.png') });
    await page.keyboard.press('b');
    await page.waitForFunction(() => document.pointerLockElement?.id === 'canvas', null, { timeout: 10000 });
    await page.keyboard.press('m');
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(screenshots, 'web-map.png') });
    await page.keyboard.press('m');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(screenshots, 'web-paused.png') });
    assert.equal(await page.evaluate(() => document.pointerLockElement), null);
    assert.deepEqual(errors, [], 'no runtime, network, or script errors');
    console.log('PASS: release loads without isolation headers; title, start, pointer capture, movement, armory, map, and pause exercised.');
  } finally {
    fs.writeFileSync(path.join(root, 'builds/web-browser-test.log'), messages.join('\n') + '\n');
    await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); server.close(); process.exitCode = 1; });
