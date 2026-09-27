/* StormRaven OS companion PWA */
(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };
  var store = {
    get url() { return localStorage.getItem('sr.serverUrl') || ''; },
    set url(v) { localStorage.setItem('sr.serverUrl', v); }
  };

  var state = { ws: null, wsTimer: null, pollTimer: null, tabTimer: null };

  /* ---------- connection ---------- */

  function baseUrl() {
    var u = store.url.replace(/\/+$/, '');
    return u;
  }

  function api(path, opts) {
    var base = baseUrl();
    if (!base) return Promise.reject(new Error('No gateway URL configured. Open Settings ⚙︎ and set the kernel gateway URL.'));
    return fetch(base + path, Object.assign({ headers: { 'Accept': 'application/json' } }, opts || {}))
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      });
  }

  function setConn(ok, text) {
    var el = $('connState'), dot = $('pulseDot');
    el.textContent = text;
    el.className = 'conn-state ' + (ok ? 'ok' : 'bad');
    dot.className = 'pulse-dot' + (ok ? ' ok' : '');
  }

  /* ---------- status view ---------- */

  function fmtUptime(sec) {
    if (sec == null) return '—';
    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
    return (d ? d + 'd ' : '') + (h ? h + 'h ' : '') + m + 'm';
  }

  function badgeFor(health) {
    var b = $('healthBadge');
    b.textContent = health;
    b.className = 'badge ' + (health === 'healthy' ? 'ok' : health === 'offline' || health === 'degraded' ? 'bad' : 'warn');
  }

  function renderStatus(s) {
    var st = s.status || s.state || s;
    var health = st.health || st.healthStatus || 'unknown';
    badgeFor(String(health).toLowerCase());
    $('kernelName').textContent = st.name || st.kernel || 'StormRaven Kernel';
    $('kernelUptime').textContent = 'uptime ' + fmtUptime(st.uptimeSec != null ? st.uptimeSec : st.uptimeSeconds);
    $('stVersion').textContent = st.version || '—';
    $('stUptime').textContent = fmtUptime(st.uptimeSec != null ? st.uptimeSec : st.uptimeSeconds);
    var provs = st.providers || [];
    $('stProviders').textContent = Array.isArray(provs) ? String(provs.length) : (provs || '—');
    var decs = s.decisions || st.recentDecisions || [];
    renderDecisions(Array.isArray(decs) ? decs : []);

    var checks = st.checks || [
      { name: 'IPC pipe', state: st.ipc ? 'ok' : 'unknown' },
      { name: 'Edge tabs provider', state: st.edgeTabs ? 'ok' : 'unknown' },
      { name: 'Decision engine', state: 'ok' },
      { name: 'SQLite storage', state: st.storage ? 'ok' : 'unknown' }
    ];
    var list = $('healthList');
    if (!Array.isArray(checks) || !checks.length) { list.innerHTML = '<div class="muted">No health checks reported.</div>'; return; }
    list.innerHTML = '';
    checks.forEach(function (c) {
      var cls = c.state === 'ok' ? 'h-ok' : c.state === 'warn' ? 'h-warn' : 'h-bad';
      var row = document.createElement('div');
      row.className = 'health-item';
      row.innerHTML = '<span>' + esc(c.name || c.check) + '</span><span class="' + cls + '">' + esc(c.state || 'unknown') + '</span>';
      list.appendChild(row);
    });
  }

  function renderDecisions(decs) {
    var feed = $('decisionsList');
    if (!decs.length) { feed.innerHTML = '<div class="muted">No decisions yet.</div>'; $('stDecisions').textContent = '0'; return; }
    $('stDecisions').textContent = String(decs.length);
    feed.innerHTML = '';
    decs.slice(0, 8).forEach(function (d) {
      var el = document.createElement('div');
      el.className = 'feed-item';
      var sev = String(d.severity || 'info').toLowerCase();
      el.innerHTML = '<span class="sev-' + esc(sev) + '">[' + esc(sev) + ']</span> ' + esc(d.summary || d.text || JSON.stringify(d)) +
        '<time>' + esc(d.id || '') + (d.time ? ' · ' + esc(String(d.time)) : '') + '</time>';
      feed.appendChild(el);
    });
  }

  function refreshStatus() {
    api('/status').then(function (s) { renderStatus(s); setConn(true, 'connected · ' + baseUrl().replace(/^https?:\/\//, '')); })
      .catch(function (e) {
        badgeFor('offline');
        setConn(false, 'offline — ' + (e.message || 'cannot reach kernel'));
        $('healthList').innerHTML = '<div class="muted">Kernel unreachable. Check the gateway URL in Settings and that the kernel (ios-companion gateway) is running.</div>';
      });
  }

  /* ---------- tabs view ---------- */

  function renderTabs(tabs) {
    var list = $('tabsList');
    var arr = Array.isArray(tabs) ? tabs : (tabs.tabs || tabs.payload && tabs.payload.tabs || []);
    if (!arr.length) { list.innerHTML = '<div class="muted">No tab signal yet — kernel offline or provider idle.</div>'; return; }
    list.innerHTML = '';
    arr.forEach(function (t) {
      var el = document.createElement('div');
      el.className = 'tab-item' + (t.isCurrent || t.current || t.active ? ' current' : '');
      el.innerHTML = '<span class="dot"></span><div style="min-width:0"><div>' + esc(t.title || t.name || 'Untitled') + '</div>' +
        '<span class="url">' + esc(t.url || t.host || '') + '</span></div>';
      list.appendChild(el);
    });
  }

  function refreshTabs() {
    api('/tabs').then(renderTabs).catch(function (e) {
      $('tabsList').innerHTML = '<div class="muted">Cannot load tabs: ' + esc(e.message) + '</div>';
    });
  }

  /* ---------- console ---------- */

  function out(text, cls) {
    var o = $('consoleOut');
    if (o.querySelector('.muted')) o.innerHTML = '';
    var l = document.createElement('div');
    l.className = 'line ' + (cls || '');
    l.textContent = text;
    o.appendChild(l);
    o.scrollTop = o.scrollHeight;
  }

  function runCommand(cmd) {
    out('❯ ' + cmd, 'cmd');
    api('/command', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: cmd, source: 'pwa', ts: new Date().toISOString() })
    }).then(function (r) {
      var resp = r.result || r.response || r.output || r;
      out(typeof resp === 'string' ? resp : JSON.stringify(resp, null, 2), 'out');
    }).catch(function (e) { out('error: ' + e.message, 'err'); });
  }

  /* ---------- websocket events ---------- */

  function connectWs() {
    if (!baseUrl()) return;
    try { if (state.ws) state.ws.close(); } catch (e) {}
    var wsUrl = baseUrl().replace(/^http/, 'ws') + '/events';
    var ws;
    try { ws = new WebSocket(wsUrl); } catch (e) { return; }
    state.ws = ws;
    ws.onopen = function () { out('event stream connected', 'sys'); };
    ws.onmessage = function (ev) {
      try {
        var msg = JSON.parse(ev.data);
        if (msg.type === 'decision' || msg.decision) renderDecisions([msg.decision || msg].concat(currentDecisions()));
        if (msg.type === 'tabs' || msg.tabs) renderTabs(msg.tabs || msg);
        if (msg.type === 'status') renderStatus(msg);
      } catch (e) { out('event: ' + ev.data, 'out'); }
    };
    ws.onclose = function () { /* reconnect via poll loop */ };
  }

  function currentDecisions() {
    var feed = $('decisionsList');
    var items = [];
    feed.querySelectorAll('.feed-item').forEach(function () { items.push({}); });
    return items; // placeholder — new decisions prepend via feed
  }

  /* ---------- settings ---------- */

  function openSettings() {
    $('serverUrl').value = store.url;
    $('settingsModal').classList.remove('hidden');
  }
  function closeSettings() { $('settingsModal').classList.add('hidden'); }
  function saveSettings() {
    var v = $('serverUrl').value.trim();
    store.url = v;
    closeSettings();
    if (v) { setConn(false, 'connecting…'); refreshStatus(); refreshTabs(); connectWs(); }
  }

  /* ---------- routing ---------- */

  function switchView(name) {
    document.querySelectorAll('.tab').forEach(function (t) { t.classList.toggle('active', t.dataset.view === name); });
    document.querySelectorAll('.view').forEach(function (v) { v.classList.toggle('active', v.id === 'view-' + name); });
    if (name === 'tabs') refreshTabs();
    if (name === 'status') refreshStatus();
  }

  /* ---------- utils ---------- */

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  /* ---------- boot ---------- */

  document.querySelectorAll('.tab').forEach(function (t) {
    t.addEventListener('click', function () { switchView(t.dataset.view); });
  });
  $('settingsBtn').addEventListener('click', openSettings);
  $('settingsCancel').addEventListener('click', closeSettings);
  $('settingsSave').addEventListener('click', saveSettings);
  $('refreshTabs').addEventListener('click', refreshTabs);
  $('consoleForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var v = $('consoleInput').value.trim();
    if (v) { runCommand(v); $('consoleInput').value = ''; }
  });

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(function () {});
  if (!store.url) { openSettings(); }
  refreshStatus();
  state.pollTimer = setInterval(refreshStatus, 10000);
  setInterval(function () { if (document.querySelector('#view-tabs.active')) refreshTabs(); }, 15000);
})();
