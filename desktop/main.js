/* StormRaven Desktop — Electron shell around the StormRavenOS PWA + kernel gateway */
const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain } = require('electron');
const path = require('path');
const { spawn, execFile } = require('child_process');
const fs = require('fs');
const http = require('http');

const GATEWAY_PORT = process.env.STORMRAVEN_GATEWAY_PORT || '8787';
const GATEWAY_URL = `http://localhost:${GATEWAY_PORT}`;

let mainWindow = null;
let kernelProc = null;
let tray = null;
let kernelMode = 'starting'; // 'starting' | 'full' | 'ui-only'

const repoRoot = path.join(__dirname, '..');

function log(...args) { console.log('[desktop]', ...args); }

/* ---------- kernel spawning (best effort) ---------- */

function findKernelEntry() {
  // Prefer a prebuilt binary; fall back to `dotnet run`.
  const candidates = [
    path.join(repoRoot, 'publish', 'StormRaven.Kernel'),
    path.join(repoRoot, 'publish', 'StormRaven.Kernel.exe'),
    path.join(repoRoot, 'StormRaven.Kernel'),
    path.join(repoRoot, 'StormRaven.Kernel.exe'),
  ];
  for (const c of candidates) {
    try { if (fs.existsSync(c)) return { kind: 'binary', cmd: c }; } catch (_) {}
  }
  try { execFileSyncSafe('dotnet', ['--version']); return { kind: 'dotnet' }; } catch (_) {}
  return null;
}

function execFileSyncSafe(cmd, args) {
  return require('child_process').execFileSync(cmd, args, { stdio: 'ignore' });
}

function startKernel() {
  const entry = findKernelEntry();
  if (!entry) {
    log('dotnet SDK / kernel binary not found — running UI-only');
    kernelMode = 'ui-only';
    notifyRenderer();
    return;
  }

  // Schema.sql must sit next to the kernel binary for the gateway to start.
  try {
    const schema = path.join(repoRoot, 'Storage', 'Schema.sql');
    const target = path.join(repoRoot, 'Schema.sql');
    if (fs.existsSync(schema) && !fs.existsSync(target)) fs.copyFileSync(schema, target);
  } catch (_) {}

  const args = entry.kind === 'dotnet' ? ['run', '--project', repoRoot] : [];
  log('spawning kernel via', entry.kind, args.join(' '));
  kernelProc = spawn(entry.kind === 'dotnet' ? 'dotnet' : entry.cmd, args, {
    cwd: repoRoot,
    env: Object.assign({}, process.env, { STORMRAVEN_GATEWAY_PORT: GATEWAY_PORT }),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  kernelProc.stdout.on('data', d => log('kernel:', String(d).trim()));
  kernelProc.stderr.on('data', d => log('kernel!:', String(d).trim()));
  kernelProc.on('exit', code => {
    log('kernel exited', code);
    kernelProc = null;
    kernelMode = 'ui-only';
    notifyRenderer();
  });

  waitForHealth(30, 1000).then(ok => {
    kernelMode = ok ? 'full' : 'ui-only';
    log('gateway health:', ok ? 'OK' : 'no response');
    notifyRenderer();
  });
}

function stopKernel() {
  if (kernelProc) { try { kernelProc.kill(); } catch (_) {} kernelProc = null; }
}

function waitForHealth(tries, delayMs) {
  return new Promise(resolve => {
    let n = 0;
    const probe = () => {
      const req = http.get(`${GATEWAY_URL}/health`, res => {
        res.resume();
        resolve(res.statusCode < 500);
      });
      req.on('error', () => {
        if (++n >= tries) return resolve(false);
        setTimeout(probe, delayMs);
      });
      req.setTimeout(1500, () => { req.destroy(); });
    };
    probe();
  });
}

/* ---------- window / tray ---------- */

function notifyRenderer() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('kernel-status', { mode: kernelMode, url: GATEWAY_URL });
  }
  updateTrayTitle();
}

function updateTrayTitle() {
  if (tray) tray.setToolTip(`StormRaven (${kernelMode})`);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    title: 'StormRaven',
    icon: path.join(__dirname, 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  // Load the PWA from webapp/ (vite-less static app).
  mainWindow.loadFile(path.join(repoRoot, 'webapp', 'index.html'));

  mainWindow.webContents.on('did-finish-load', () => {
    // Seed the PWA's gateway URL so it connects without manual setup,
    // then install a small kernel-status badge (Electron-only).
    mainWindow.webContents.executeJavaScript(`
      try { localStorage.setItem('sr.serverUrl', ${JSON.stringify(GATEWAY_URL)}); } catch (e) {}
      (function () {
        if (document.getElementById('sr-desktop-badge')) return;
        var el = document.createElement('div');
        el.id = 'sr-desktop-badge';
        el.style.cssText = 'position:fixed;bottom:10px;right:10px;z-index:99999;font:12px/1.4 sans-serif;padding:4px 10px;border-radius:12px;background:#222;color:#eee;opacity:.85;pointer-events:none;';
        document.body.appendChild(el);
        var set = function (s) { el.textContent = s; };
        set('kernel: starting…');
        if (window.stormravenDesktop && window.stormravenDesktop.onStatus) {
          window.stormravenDesktop.onStatus(function (st) {
            set(st.mode === 'full' ? '● kernel + gateway on ' + st.url
              : st.mode === 'ui-only' ? '○ UI-only (kernel not running)'
              : 'kernel: starting…');
          });
        }
      })();
    `).then(notifyRenderer).catch(() => {});
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

function createTray() {
  const iconPath = path.join(__dirname, 'icon.png');
  if (!fs.existsSync(iconPath)) return;
  tray = new Tray(nativeImage.createFromPath(iconPath));
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'Open StormRaven', click: () => (mainWindow ? mainWindow.show() : createWindow()) },
    { label: `Gateway: ${GATEWAY_URL}`, enabled: false },
    { type: 'separator' },
    { label: 'Quit', click: () => app.quit() },
  ]));
  updateTrayTitle();
}

app.whenReady().then(() => {
  createWindow();
  createTray();
  startKernel();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

ipcMain.handle('kernel-status', () => ({ mode: kernelMode, url: GATEWAY_URL }));

app.on('window-all-closed', () => {
  // Keep running in tray on macOS/Windows; quit on Linux.
  if (process.platform !== 'darwin' && !tray) app.quit();
});

app.on('before-quit', stopKernel);
process.on('exit', stopKernel);
