// Zips the extension for a store upload or "Load unpacked": node scripts/pack.js
const { execFileSync } = require('node:child_process');
const { mkdirSync } = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const out = path.join(root, 'dist');
mkdirSync(out, { recursive: true });
const files = ['manifest.json', 'background.js', 'bridge.js', 'core.js', 'hosts.js', 'reader.js', 'options.html', 'options.js', 'icons'];
execFileSync('zip', ['-qr', path.join(out, 'bhojana-extension.zip'), ...files], { cwd: root });
console.log('dist/bhojana-extension.zip');
