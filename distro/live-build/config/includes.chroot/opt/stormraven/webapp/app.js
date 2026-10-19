/* StormRaven OS Mobile PWA — Bifrost v1 + Odin Python Pantheon */
(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };
  var defaultOrigin = (typeof window !== 'undefined' && window.location && window.location.origin && window.location.origin.indexOf('http') === 0)
    ? window.location.origin
    : 'https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app';

  var store = {
    get url() { return localStorage.getItem('sr.serverUrl') || defaultOrigin; },
    set url(v) {
      if (!v) localStorage.removeItem('sr.serverUrl');
      else localStorage.setItem('sr.serverUrl', v);
    }
  };

  var state = { ws: null, pollTimer: null, decisions: [], tabs: [] };

  function baseUrl() {
    return (store.url || defaultOrigin).replace(/\/+$/, '');
  }

  function unwrap(json) {
    if (json && typeof json === 'object' && json.ok === true && json.data !== undefined) {
      return json.data;
    }
    return json;
  }

  function api(path, opts) {
    var base = baseUrl();
    return fetch(base + path, Object.assign({ headers: { 'Accept': 'application/json' } }, opts || {}))
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      });
  }

  function setConn(ok, text) {
    var el = $('connState'), dot = $('pulseDot');
    if (el) {
      el.textContent = text;
      el.className = 'conn-state ' + (ok ? 'ok' : 'bad');
    }
    if (dot) {
      dot.className = 'pulse-dot' + (ok ? ' ok' : '');
    }
  }

  function fmtUptime(sec) {
    if (sec == null) return '—';
    var s = Number(sec);
    var d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
    if (d === 0 && h === 0 && m === 0) return s + 's';
    return (d ? d + 'd ' : '') + (h ? h + 'h ' : '') + m + 'm';
  }

  function badgeFor(health) {
    var b = $('healthBadge');
    if (!b) return;
    b.textContent = health;
    var ok = (health === 'healthy' || health === 'online' || health === 'ok');
    var bad = (health === 'offline' || health === 'degraded' || health === 'error');
    b.className = 'badge ' + (ok ? 'ok' : bad ? 'bad' : 'warn');
  }

  function renderStatus(raw) {
    var s = unwrap(raw);
    var st = s.status && typeof s.status === 'object' ? s.status : s;
    var healthStr = String(st.health || st.status || 'online').toLowerCase();
    badgeFor(healthStr === 'online' ? 'healthy' : healthStr);

    var kName = st.distro || st.name || st.kernel || 'StormRaven OS (Ubuntu 24.04 Noble)';
    $('kernelName').textContent = kName;
    var up = st.uptimeSec != null ? st.uptimeSec : st.uptimeSeconds;
    $('kernelUptime').textContent = 'uptime ' + fmtUptime(up) + ' · bridge ' + (st.bridgeVersion || 'sr.bridge.mobile.v1');
    $('stVersion').textContent = (st.distroVersion || '24.04 Noble') + ' · v' + (st.version || '1.0.0');
    $('stUptime').textContent = fmtUptime(up);

    var openTabsCount = st.openTabs != null ? st.openTabs : (Array.isArray(st.tabs) ? st.tabs.length : state.tabs.length);
    $('stProviders').textContent = String(openTabsCount) + ' active';

    if (st.telemetry) {
      if ($('odinCpu')) $('odinCpu').textContent = st.telemetry.cpu + '%';
      if ($('odinRam')) $('odinRam').textContent = st.telemetry.ram + '%';
    }
    if (st.linuxKernel && $('odinKernelVer')) {
      $('odinKernelVer').textContent = st.linuxKernel;
    }

    var decs = s.decisions || st.recentDecisions || state.decisions || [];
    if (Array.isArray(decs) && decs.length) {
      state.decisions = decs;
      renderDecisions(decs);
    }

    var checks = st.checks || [
      { name: 'Bifrost Mobile Gateway (:8787)', state: 'ok' },
      { name: 'Ubuntu 24.04 LTS (Noble) Runtime', state: 'ok' },
      { name: 'Edge Tabs Signal Provider', state: 'ok' },
      { name: 'Deterministic DecisionEngine', state: 'ok' },
      { name: 'Odin Python Pantheon (Thor/Freya/Heimdall)', state: 'ok' },
      { name: 'SQLite Decision Store', state: 'ok' }
    ];
    var list = $('healthList');
    if (list) {
      list.innerHTML = '';
      checks.forEach(function (c) {
        var cls = c.state === 'ok' ? 'h-ok' : c.state === 'warn' ? 'h-warn' : 'h-bad';
        var row = document.createElement('div');
        row.className = 'health-item';
        row.innerHTML = '<span>' + esc(c.name || c.check) + '</span><span class="' + cls + '">' + esc(c.state || 'ok') + '</span>';
        list.appendChild(row);
      });
    }
  }

  function renderDecisions(decs) {
    var arr = Array.isArray(decs) ? decs : (decs && decs.decisions ? decs.decisions : []);
    state.decisions = arr;
    if ($('stDecisions')) $('stDecisions').textContent = String(arr.length);

    ['decisionsList', 'fullDecisionsList'].forEach(function (targetId) {
      var feed = $(targetId);
      if (!feed) return;
      if (!arr.length) {
        feed.innerHTML = '<div class="muted">No decisions recorded yet.</div>';
        return;
      }
      feed.innerHTML = '';
      var limit = targetId === 'decisionsList' ? 5 : 25;
      arr.slice(0, limit).forEach(function (d) {
        var el = document.createElement('div');
        el.className = 'feed-item';
        var sev = String(d.severity || 'info').toLowerCase();
        var rule = (d.explainability && d.explainability.ruleId) ? ' · rule: ' + d.explainability.ruleId : (d.ruleId ? ' · rule: ' + d.ruleId : '');
        el.innerHTML = '<span class="sev-' + esc(sev) + '">[' + esc(sev.toUpperCase()) + ']</span> ' +
          esc(d.summary || d.text || JSON.stringify(d)) +
          '<time>' + esc(d.id || '') + (d.time ? ' · ' + esc(String(d.time)) : '') + esc(rule) + '</time>';
        feed.appendChild(el);
      });
    });
  }

  function refreshStatus() {
    api('/status')
      .then(function (s) {
        renderStatus(s);
        var hostLabel = baseUrl().replace(/^https?:\/\//, '');
        setConn(true, 'connected · ' + hostLabel);
      })
      .catch(function () {
        // Fallback directly to Bifrost v1 /health + /decisions
        return Promise.all([api('/health'), api('/decisions').catch(function () { return {}; })])
          .then(function (res) {
            var h = unwrap(res[0]);
            var d = unwrap(res[1]);
            h.decisions = d.decisions || [];
            renderStatus(h);
            setConn(true, 'connected · ' + baseUrl().replace(/^https?:\/\//, ''));
          });
      })
      .catch(function (e) {
        badgeFor('offline');
        setConn(false, 'offline — ' + (e.message || 'cannot reach kernel'));
      });
  }

  /* ---------- tabs view ---------- */

  function renderTabs(raw) {
    var list = $('tabsList');
    if (!list) return;
    var unwrapped = unwrap(raw);
    var arr = Array.isArray(unwrapped) ? unwrapped : (unwrapped.tabs || (unwrapped.payload && unwrapped.payload.tabs) || []);
    state.tabs = arr;
    if ($('stProviders')) $('stProviders').textContent = String(arr.length) + ' active';
    if (!arr.length) {
      list.innerHTML = '<div class="muted">No tab signal yet — tap "+ Demo Tab" to ingest a live mobile tab signal.</div>';
      return;
    }
    list.innerHTML = '';
    arr.forEach(function (t) {
      var isCur = Boolean(t.isCurrent || t.current || t.active);
      var el = document.createElement('div');
      el.className = 'tab-item' + (isCur ? ' current' : '');
      el.innerHTML =
        '<div class="tab-main">' +
          '<span class="dot"></span>' +
          '<div style="min-width:0">' +
            '<div style="font-weight:600">' + esc(t.title || t.name || 'Untitled') + '</div>' +
            '<span class="url">' + esc(t.url || t.host || '') + '</span>' +
          '</div>' +
        '</div>' +
        (isCur ? '<span class="tab-badge">FOCUSED</span>' : '');
      list.appendChild(el);
    });
  }

  function refreshTabs() {
    api('/tabs').then(renderTabs).catch(function (e) {
      if ($('tabsList')) $('tabsList').innerHTML = '<div class="muted">Cannot load tabs: ' + esc(e.message) + '</div>';
    });
  }

  function refreshDecisions() {
    api('/decisions').then(function (r) {
      var d = unwrap(r);
      renderDecisions(d.decisions || d);
    }).catch(function () {});
  }

  function ingestDemoTab() {
    var now = new Date().toISOString();
    var demoTabs = [
      { id: 'mob-core', title: 'StormRaven OS Mobile — Bifrost Active Session', url: baseUrl() + '/', isCurrent: true, isAudible: false, updatedUtc: now },
      { id: 'mob-repo', title: 'faithjennings055-cmyk/StormRaven-OS-Core- (Ubuntu 24.04 Noble)', url: 'https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-', isCurrent: false, isAudible: false, updatedUtc: now },
      { id: 'mob-odin', title: 'Odin Leviathan Core v5.0 — Pantheon Telemetry', url: 'stormraven://pantheon/odin', isCurrent: false, isAudible: false, updatedUtc: now }
    ];
    api('/tabs', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(demoTabs)
    }).then(function (res) {
      refreshTabs();
      refreshStatus();
      refreshDecisions();
      if ($('odinOutput')) {
        $('odinOutput').textContent = JSON.stringify(unwrap(res), null, 2);
      }
    }).catch(function (err) {
      out('ingest error: ' + err.message, 'err');
    });
  }

  function evaluateNow() {
    runCommand('evaluate', true);
  }

  /* ---------- console & Odin Pantheon ---------- */

  function out(text, cls) {
    var o = $('consoleOut');
    if (!o) return;
    if (o.querySelector('.muted')) o.innerHTML = '';
    var l = document.createElement('div');
    l.className = 'line ' + (cls || '');
    l.textContent = text;
    o.appendChild(l);
    o.scrollTop = o.scrollHeight;
  }

  function runCommand(cmd, alsoUpdateOdinBox) {
    out('❯ ' + cmd, 'cmd');
    if (alsoUpdateOdinBox && $('odinOutput')) {
      $('odinOutput').textContent = 'Running ' + cmd + '…';
    }
    return api('/command', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: cmd, source: 'mobile-pwa', ts: new Date().toISOString() })
    }).then(function (r) {
      var payload = r.result || r.response || r.output || unwrap(r);
      var formatted = typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2);
      out(formatted, 'out');
      if (alsoUpdateOdinBox && $('odinOutput')) {
        $('odinOutput').textContent = formatted;
      }
      if (payload && payload.telemetry) {
        if ($('odinCpu')) $('odinCpu').textContent = payload.telemetry.cpu + '%';
        if ($('odinRam')) $('odinRam').textContent = payload.telemetry.ram + '%';
      }
      refreshStatus();
      refreshDecisions();
      return payload;
    }).catch(function (e) {
      out('error: ' + e.message, 'err');
      if (alsoUpdateOdinBox && $('odinOutput')) {
        $('odinOutput').textContent = 'Error: ' + e.message;
      }
    });
  }

  /* ---------- websocket events ---------- */

  function connectWs() {
    if (!baseUrl()) return;
    try { if (state.ws) state.ws.close(); } catch (e) {}
    var wsUrl = baseUrl().replace(/^http/, 'ws') + '/ws';
    var ws;
    try { ws = new WebSocket(wsUrl); } catch (e) { return; }
    state.ws = ws;
    ws.onopen = function () { out('● bifrost live stream connected (/ws)', 'sys'); };
    ws.onmessage = function (ev) {
      try {
        var msg = JSON.parse(ev.data);
        if (msg.type === 'hello') {
          if (msg.tabs) renderTabs(msg.tabs);
          refreshStatus();
        } else if (msg.type === 'decision' && msg.data) {
          state.decisions = [msg.data].concat(state.decisions);
          renderDecisions(state.decisions);
        } else if (msg.type === 'tabs' || msg.tabs) {
          renderTabs(msg.tabs || msg.data || msg);
        } else if (msg.type === 'health.tick' && msg.data) {
          renderStatus(msg.data);
        }
      } catch (e) {}
    };
    ws.onclose = function () {};
  }

  /* ---------- settings ---------- */

  function openSettings() {
    $('serverUrl').value = store.url;
    $('settingsModal').classList.remove('hidden');
  }
  function closeSettings() { $('settingsModal').classList.add('hidden'); }
  function saveSettings() {
    var v = $('serverUrl').value.trim();
    store.url = v || defaultOrigin;
    closeSettings();
    setConn(false, 'connecting…');
    refreshStatus();
    refreshTabs();
    refreshDecisions();
    connectWs();
  }

  /* ---------- routing ---------- */

  function switchView(name) {
    document.querySelectorAll('.tab').forEach(function (t) { t.classList.toggle('active', t.dataset.view === name); });
    document.querySelectorAll('.view').forEach(function (v) { v.classList.toggle('active', v.id === 'view-' + name); });
    if (name === 'tabs') refreshTabs();
    if (name === 'status') refreshStatus();
    if (name === 'decisions') refreshDecisions();
    if (name === 'odin') runCommand('odin telemetry', true);
  }

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
  if ($('ingestDemoTabBtn')) $('ingestDemoTabBtn').addEventListener('click', ingestDemoTab);
  if ($('evalQuickBtn')) $('evalQuickBtn').addEventListener('click', evaluateNow);
  if ($('evalEngineBtn')) $('evalEngineBtn').addEventListener('click', evaluateNow);

  document.querySelectorAll('[data-odin]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var act = btn.getAttribute('data-odin');
      if (act === 'ingest_demo_tab') {
        ingestDemoTab();
      } else if (act === 'evaluate' || act === 'ping') {
        runCommand(act, true);
      } else {
        runCommand('odin ' + act, true);
      }
    });
  });

  if ($('installCmdText')) {
    $('installCmdText').textContent = 'curl -fsSL ' + baseUrl() + '/install-mobile.sh | bash';
  }
  if ($('copyInstallBtn')) {
    $('copyInstallBtn').addEventListener('click', function () {
      var txt = $('installCmdText').textContent;
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(function () {
          $('copyInstallBtn').textContent = 'Copied!';
          setTimeout(function () { $('copyInstallBtn').textContent = 'Copy'; }, 1800);
        });
      }
    });
  }

  $('consoleForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var v = $('consoleInput').value.trim();
    if (v) { runCommand(v, false); $('consoleInput').value = ''; }
  });

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(function () {});

  // Connect immediately to same-origin (or saved URL) with zero modal pop-up!
  refreshStatus();
  refreshTabs();
  refreshDecisions();
  connectWs();
  state.pollTimer = setInterval(refreshStatus, 10000);
})();
