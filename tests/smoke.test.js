// Smoke test for index.html.
// Loads the page in jsdom, runs the inline app script, and asserts the
// expected structure and theming behaviour. No browser, no network.

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { JSDOM } = require('jsdom');

const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');

const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  url: 'http://localhost/',
  beforeParse(window) {
    // jsdom does not implement matchMedia; the app calls it during startup.
    window.matchMedia = (query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener() {},
      removeListener() {},
      addEventListener() {},
      removeEventListener() {},
      dispatchEvent() { return false; },
    });
    // Chart.js is loaded from a CDN that jsdom does not fetch. Stub it so the
    // app's deferred chart-rendering calls no-op instead of throwing.
    window.Chart = class {
      destroy() {}
      update() {}
      resize() {}
    };
  },
});
const { document } = dom.window;

let failures = 0;
function check(name, fn) {
  try {
    fn();
    console.log(`  ok  ${name}`);
  } catch (err) {
    failures += 1;
    console.error(`  FAIL  ${name}`);
    console.error(`        ${err.message}`);
    process.exitCode = 1;
  }
}

// Give the inline <script> a moment to register listeners + run startup.
dom.window.addEventListener('load', () => {
  console.log('Running smoke tests...');

  // ---- DOCUMENT SHELL ----
  check('page has the Peso Smart title', () => {
    assert.strictEqual(document.title, 'Peso Smart');
  });

  check('html declares a language', () => {
    assert.strictEqual(document.documentElement.getAttribute('lang'), 'en');
  });

  // ---- PWA WIRING ----
  check('manifest, theme-color and apple-touch-icon are linked', () => {
    const manifest = document.querySelector('link[rel="manifest"]');
    assert.ok(manifest, 'a <link rel="manifest"> must be present');
    assert.strictEqual(manifest.getAttribute('href'), 'manifest.json');

    const themeColor = document.querySelector('meta[name="theme-color"]');
    assert.ok(themeColor, 'a theme-color meta tag must be present');

    const touchIcon = document.querySelector('link[rel="apple-touch-icon"]');
    assert.ok(touchIcon, 'an apple-touch-icon link must be present');
  });

  check('service worker registration points at sw.js', () => {
    assert.ok(/navigator\.serviceWorker\.register\(\s*["']sw\.js["']/.test(html),
      'index.html must register sw.js');
  });

  // ---- THEME (light/dark toggle) ----
  check('both theme palettes are defined and the toggle button exists', () => {
    const btn = document.getElementById('themeToggle');
    assert.ok(btn, 'header must have a #themeToggle button');
    assert.ok(btn.getAttribute('aria-label'), 'toggle needs an accessible name');
    assert.ok(/\[data-theme="light"\]/.test(html),
      'a [data-theme="light"] token set must be defined');
    assert.ok(/\[data-theme="dark"\]/.test(html),
      'a [data-theme="dark"] token set must be defined');
  });

  check('toggleTheme + applyTheme are exposed and switch the data-theme attribute', () => {
    assert.strictEqual(typeof dom.window.toggleTheme, 'function',
      'toggleTheme must be a global function');
    assert.strictEqual(typeof dom.window.applyTheme, 'function',
      'applyTheme must be a global function');

    dom.window.applyTheme('dark');
    assert.strictEqual(document.documentElement.getAttribute('data-theme'), 'dark');

    dom.window.applyTheme('light');
    assert.strictEqual(document.documentElement.getAttribute('data-theme'), 'light');
  });

  if (failures === 0) {
    console.log('All smoke tests passed.');
  } else {
    console.error(`${failures} smoke test(s) failed.`);
  }
});
