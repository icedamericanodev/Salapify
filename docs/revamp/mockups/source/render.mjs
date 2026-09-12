import { chromium } from 'playwright-core';
import fs from 'node:fs';
const files = process.argv.slice(2).length ? process.argv.slice(2) : ['home', 'log', 'accounts', 'plan', 'utang', 'home-dark'];
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const page = await browser.newPage({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 2 });
for (const f of files) {
  await page.goto('file://' + process.cwd() + '/' + f + '.html', { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(400);
  const overflow = await page.evaluate(() => {
    const out = [];
    for (const el of document.querySelectorAll('.content *')) {
      if (el.scrollWidth > el.clientWidth + 1 && getComputedStyle(el).overflow === 'visible' && el.children.length === 0) out.push(el.className + ': ' + el.textContent.trim().slice(0, 40));
    }
    return out;
  });
  await page.screenshot({ path: 'shots/' + f + '.png' });
  console.log('shot', f, overflow.length ? 'OVERFLOW ' + JSON.stringify(overflow) : 'ok');
}
await browser.close();
