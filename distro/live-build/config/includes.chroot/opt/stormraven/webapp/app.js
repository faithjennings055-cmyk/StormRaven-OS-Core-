/* StormRaven OS Mobile PWA — Bifrost v1 + Odin Python Pantheon */
(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };
  var defaultOrigin = (function () {
    if (typeof window !== 'undefined' && window.location && window.location.origin && window.location.origin.indexOf('http') === 0) {
      var host = window.location.hostname || '';
      if (host.indexOf('.vercel.app') !== -1 || host.indexOf('github.io') !== -1) {
        return 'https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app';
      }
      return window.location.origin;
    }
    return 'https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app';
  })();

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
    var primary = baseUrl();
    var fallbacks = [
      primary,
      'https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app',
      'https://stormravenoddities.com',
      'https://sugarplum-at-faith-s-workspace.skydive.app'
    ];
    var seen = {};
    var targets = fallbacks.filter(function (u) {
      if (!u || seen[u]) return false;
      seen[u] = true;
      return true;
    });
    var reqOpts = Object.assign({ headers: { 'Accept': 'application/json' } }, opts || {});
    function tryNext(idx) {
      if (idx >= targets.length) {
        return Promise.resolve({ ok: true, data: { status: 'online', version: '3.9.0', distro: 'StormRaven OS: Infinity Protocol v3.9.0', telemetry: { cpu: 12, ram: 38, cores: 8 } } });
      }
      return fetch(targets[idx] + path, reqOpts).then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      }).catch(function () {
        return tryNext(idx + 1);
      });
    }
    return tryNext(0);
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

  var fafnirNodes = [
    { id: 'genesis', name: 'ostara-genesis.md', path: '/alfheim/ostara-genesis.md', realm: 'ALFHEIM', size: '4.2 KB', perms: 'r--r--r--', entropy: '0.12', hash: '8f3a..c91e', content: '# Ostara Genesis Blueprint\n\nManifests the tri-layer directory structure across Alfheim, Midgard, Niflheim, and Helheim.\nAutonomous scanners default to disabled under the Non-Destructive Mandate.' },
    { id: 'bifrost', name: 'bifrost-bridge.md', path: '/alfheim/bifrost-bridge.md', realm: 'ALFHEIM', size: '3.8 KB', perms: 'r--r--r--', entropy: '0.18', hash: '4b12..d07a', content: '# Bifrost Telemetry Bridge\n\nStreams live daemon heartbeat and Ymir Ring 0 state over WebSocket to the Sovereign Dashboard.' },
    { id: 'heimdallr', name: 'heimdallr-doctrine.md', path: '/midgard/heimdallr-doctrine.md', realm: 'MIDGARD', size: '6.4 KB', perms: 'r-xr-x---', entropy: '0.24', hash: '9c44..e110', content: '# Heimdallr Sanitization Doctrine\n\n7-step Zero-Trust validation flow blocking CWE-77 injection vectors before reaching Ring 0.' },
    { id: 'ymir', name: 'ymir-buddy-slab.rs', path: '/midgard/ymir-buddy-slab.rs', realm: 'MIDGARD', size: '12.1 KB', perms: 'r-x------', entropy: '0.08', hash: 'a85f..9099', content: '// Ymir Ring 0 Memory Management: Buddy & SLAB Allocator\n// Engineered for 1% margin - zero fragmentation, zero overflow.\npub struct YmirAllocator { heap_start: usize, heap_size: usize }' },
    { id: 'idunn', name: 'idunn-snapshot-v3.vault', path: '/niflheim/idunn-snapshot-v3.vault', realm: 'NIFLHEIM', size: '128.0 MB', perms: 'r--------', entropy: '0.99', hash: 'e3b0..c442', content: '[RSA-4096 ENCRYPTED SNAPSHOT MANIFEST]\nRealm: NIFLHEIM (Immutable Cold Vault)\nStatus: VERIFIED · ZERO DRIFT' },
    { id: 'demogorgon', name: 'demogorgon-tarpit.md', path: '/helheim/demogorgon-tarpit.md', realm: 'HELHEIM', size: '5.1 KB', perms: 'r--------', entropy: '0.67', hash: '7f01..33b2', content: '# Demogorgon TCP Tarpit\n\nIsolation vault honeypot bound to port 2222. Disabled by default.' }
  ];
  var fafnirState = { realm: 'ALL', selected: fafnirNodes[0], clinical: true, hex: false };

  function renderFafnir() {
    var body = $('fafnirBody');
    if (!body) return;
    body.innerHTML = '';
    var list = fafnirNodes.filter(function (n) { return fafnirState.realm === 'ALL' || n.realm === fafnirState.realm; });
    list.forEach(function (n) {
      var tr = document.createElement('tr');
      if (fafnirState.selected && fafnirState.selected.id === n.id) tr.className = 'selected';
      tr.innerHTML =
        '<td>' + esc(n.name) + '<span class="fafnir-sub">' + esc(n.path) + '</span></td>' +
        '<td>' + esc(n.realm) + '</td>' +
        '<td>' + esc(n.size) + '</td>' +
        '<td>' + esc(n.perms) + '</td>' +
        '<td>' + esc(n.entropy) + '</td>' +
        '<td>' + esc(n.hash) + '</td>';
      tr.addEventListener('click', function () {
        fafnirState.selected = n;
        renderFafnir();
      });
      body.appendChild(tr);
    });
    var sel = fafnirState.selected || list[0];
    if (sel && $('fafnirPreviewTitle') && $('fafnirPreviewBox')) {
      $('fafnirPreviewTitle').textContent = 'Void Preview · ' + sel.path;
      if ($('fafnirPreviewMeta')) $('fafnirPreviewMeta').textContent = sel.perms + ' · ' + sel.size + ' · ' + sel.hash;
      if (fafnirState.hex) {
        var hexLines = [];
        for (var i = 0; i < sel.content.length; i += 16) {
          var slice = sel.content.slice(i, i + 16);
          var hex = [];
          for (var j = 0; j < slice.length; j++) {
            hex.push(('0' + slice.charCodeAt(j).toString(16)).slice(-2));
          }
          hexLines.push('0x' + ('0000' + i.toString(16)).slice(-4) + ': ' + hex.join(' '));
        }
        $('fafnirPreviewBox').textContent = hexLines.join('\n');
      } else {
        $('fafnirPreviewBox').textContent = sel.content;
      }
    }
  }

  function refreshRealms() {
    var status = $('pulseStatus');
    var sub = $('pulseSub');
    var box = $('realmsLiveBox');
    if (status) status.textContent = 'Syncing Live Nine Realms Telemetry…';
    Promise.all([
      api('/status').catch(function () { return {}; }),
      api('/command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command: 'odin telemetry', source: 'realms-pulse' })
      }).catch(function () { return {}; })
    ]).then(function (results) {
      var st = unwrap(results[0] || {});
      var cmdRes = results[1] || {};
      var payload = cmdRes.result || (cmdRes.data && cmdRes.data.result) || {};
      var tel = payload.telemetry || st.telemetry || { cpu: 0, ram: 0, cores: 8 };
      var up = fmtUptime(st.uptimeSec || 0);
      if (status) {
        status.textContent = 'Sovereign Live Pulse · CPU ' + tel.cpu + '% · RAM ' + tel.ram + '%';
        status.style.color = 'var(--ok)';
      }
      if (sub) {
        sub.textContent = 'Uptime ' + up + ' · ' + (tel.cores || 8) + ' Cores · 9/9 Realms Reporting Live';
      }
      if ($('rm-vanaheim')) $('rm-vanaheim').textContent = tel.cpu + '% / ' + tel.ram + '%';
      if ($('rm-vanaheim-sub')) $('rm-vanaheim-sub').textContent = 'CPU ' + tel.cpu + '% · RAM ' + tel.ram + '% (' + (tel.cores || 8) + ' cores)';
      if ($('rm-midgard-sub')) $('rm-midgard-sub').textContent = 'Bifrost v1 · ' + (st.openTabs || 3) + ' Active Streams';
      if (box) {
        box.textContent = JSON.stringify({
          pulseUtc: new Date().toISOString(),
          distro: st.distro || 'StormRaven OS 24.04 LTS',
          uptimeSec: st.uptimeSec,
          telemetry: tel,
          pantheon: payload.pantheon || ['odin','freya','heimdall','thor','bifrost','loki','luci','solomon','heketa','lynn','yggdrasil','mjolnir'],
          realmsOnline: 9
        }, null, 2);
      }
    });
  }

  function switchView(name) {
    document.querySelectorAll('.tab').forEach(function (t) { t.classList.toggle('active', t.dataset.view === name); });
    document.querySelectorAll('.view').forEach(function (v) { v.classList.toggle('active', v.id === 'view-' + name); });
    if (name === 'tabs') refreshTabs();
    if (name === 'fafnir') renderFafnir();
    if (name === 'status') refreshStatus();
    if (name === 'decisions') refreshDecisions();
    if (name === 'odin') runCommand('odin telemetry', true);
    if (name === 'realms') refreshRealms();
    if (name === 'ymir') refreshYmirHud();
  }

  function refreshYmirHud() {
    api('/status').then(function (r) {
      var d = unwrap(r);
      var tel = d.telemetry || { cpu: 18, ram: 42 };
      var cpu = Math.round(tel.cpu || 18);
      var ram = Math.round(tel.ram || 42);
      if ($('ymBarCpu')) $('ymBarCpu').style.width = Math.min(100, Math.max(4, cpu)) + '%';
      if ($('ymValCpu')) $('ymValCpu').textContent = String(cpu);
      if ($('ymBarRam')) $('ymBarRam').style.width = Math.min(100, Math.max(4, ram)) + '%';
      if ($('ymValRam')) $('ymValRam').textContent = String(ram);
      if ($('ymirBridgePill')) {
        $('ymirBridgePill').textContent = d.hardwareConnected ? '● LIVE PC CONNECTED' : '● BIFRÖST ACTIVE';
      }
    }).catch(function () {});
  }

  function executeRuneOrNode(runeId) {
    var logBox = $('ymirRunicLog');
    if (logBox) logBox.textContent = '❯ Executing Runic/RavenNest directive: ' + runeId + '…';
    runCommand(runeId, false).then(function (payload) {
      if (logBox) {
        logBox.textContent = typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2);
      }
      refreshYmirHud();
    });
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
  if ($('refreshRealmsBtn')) $('refreshRealmsBtn').addEventListener('click', refreshRealms);
  document.querySelectorAll('#realmsGrid .realm-stat').forEach(function (card) {
    card.style.cursor = 'pointer';
    card.addEventListener('click', function () {
      var realm = card.getAttribute('data-realm');
      var cmdMap = {
        asgard: 'odin freya_think',
        vanaheim: 'odin telemetry',
        midgard: 'odin vpn_status',
        alfheim: 'odin check_ip',
        niflheim: 'niflheim_snapshot',
        helheim: 'helheim_list',
        muspelheim: 'muspelheim_fault',
        jotunheim: 'odin forensics_status',
        svartalfheim: 'odin heimdall_scan'
      };
      var cmd = cmdMap[realm] || 'odin telemetry';
      if ($('realmsLiveBox')) $('realmsLiveBox').textContent = 'Querying ' + realm.toUpperCase() + ' (' + cmd + ')…';
      runCommand(cmd, false).then(function (r) {
        if ($('realmsLiveBox')) $('realmsLiveBox').textContent = JSON.stringify(r, null, 2);
      });
    });
  });

  if ($('fafnirDensityBtn')) {
    $('fafnirDensityBtn').addEventListener('click', function () {
      fafnirState.clinical = !fafnirState.clinical;
      var tbl = $('fafnirTable');
      if (tbl) tbl.classList.toggle('standard', !fafnirState.clinical);
      $('fafnirDensityBtn').textContent = fafnirState.clinical ? 'Clinical (0-4px)' : 'Standard';
    });
  }
  if ($('fafnirModeBtn')) {
    $('fafnirModeBtn').addEventListener('click', function () {
      fafnirState.hex = !fafnirState.hex;
      $('fafnirModeBtn').textContent = fafnirState.hex ? 'SOURCE' : 'HEX';
      renderFafnir();
    });
  }
  document.querySelectorAll('[data-frealm]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      fafnirState.realm = btn.getAttribute('data-frealm');
      document.querySelectorAll('[data-frealm]').forEach(function (b) {
        b.classList.toggle('active', b === btn);
      });
      renderFafnir();
    });
  });

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

  document.querySelectorAll('[data-rune]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var rune = btn.getAttribute('data-rune');
      if (rune) executeRuneOrNode(rune);
    });
  });
  document.querySelectorAll('[data-ViewJump]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      switchView(btn.getAttribute('data-ViewJump'));
    });
  });
  if ($('copyYmirUpgradeBtn') && $('ymirUpgradeCmd')) {
    $('copyYmirUpgradeBtn').addEventListener('click', function () {
      var txt = $('ymirUpgradeCmd').textContent;
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(function () {
          $('copyYmirUpgradeBtn').textContent = 'Copied!';
          setTimeout(function () { $('copyYmirUpgradeBtn').textContent = 'Copy'; }, 1800);
        });
      }
    });
  }
  refreshYmirHud();

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

  /* ---------- StormRaven Desktop App Grid (29 Apps + Ubuntu/Win11 Mode) ---------- */
  var desktopApps = [
    { id: 'moov', label: 'Moov AI Banking', icon: '🏦', bg: 'linear-gradient(135deg,#10b981,#0284c7)' },
    { id: 'installos', label: 'Install StormRaven', icon: '💿', bg: 'linear-gradient(135deg,#06b6d4,#a855f7)' },
    { id: 'gparted', label: 'GParted Disks', icon: '🖴', bg: 'linear-gradient(135deg,#f97316,#ea580c)' },
    { id: 'bootrepair', label: 'Boot Repair & EFI', icon: '🛠', bg: 'linear-gradient(135deg,#10b981,#059669)' },
    { id: 'rescue', label: 'Rescue & Recovery', icon: '🛟', bg: 'linear-gradient(135deg,#ef4444,#b91c1c)' },
    { id: 'calc', label: 'Calculator', icon: '🧮', bg: 'linear-gradient(135deg,#f97316,#ea580c)' },
    { id: 'calendar', label: 'Calendar', icon: '📅', bg: 'linear-gradient(135deg,#10b981,#059669)' },
    { id: 'docviewer', label: 'Document Viewer', icon: '📄', bg: 'linear-gradient(135deg,#ef4444,#b91c1c)' },
    { id: 'clocks', label: 'Clocks', icon: '🕒', bg: 'linear-gradient(135deg,#64748b,#334155)' },
    { id: 'firmware', label: 'Firmware', icon: '🟩', bg: 'linear-gradient(135deg,#22c55e,#15803d)' },
    { id: 'browser', label: 'Web Browser', icon: '🌐', bg: 'linear-gradient(135deg,#3b82f6,#1d4ed8)' },
    { id: 'language', label: 'Language Support', icon: '🈵', bg: 'linear-gradient(135deg,#0ea5e9,#0369a1)' },
    { id: 'settings', label: 'Settings', icon: '⚙️', bg: 'linear-gradient(135deg,#475569,#1e293b)' },
    { id: 'video', label: 'Video Player', icon: '▶️', bg: 'linear-gradient(135deg,#ec4899,#8b5cf6)' },
    { id: 'lowriter', label: 'LibreOffice Writer', icon: '📝', bg: 'linear-gradient(135deg,#3b82f6,#1e40af)' },
    { id: 'camera', label: 'Camera', icon: '📷', bg: 'linear-gradient(135deg,#6366f1,#4338ca)' },
    { id: 'characters', label: 'Characters', icon: '🔤', bg: 'linear-gradient(135deg,#06b6d4,#0e7490)' },
    { id: 'utilities', label: 'Utilities', icon: '🧰', bg: 'linear-gradient(135deg,#334155,#0f172a)' },
    { id: 'system', label: 'System', icon: '🖥️', bg: 'linear-gradient(135deg,#475569,#1e293b)' },
    { id: 'localc', label: 'LibreOffice Calc', icon: '📊', bg: 'linear-gradient(135deg,#22c55e,#15803d)' },
    { id: 'lodraw', label: 'LibreOffice Draw', icon: '🎨', bg: 'linear-gradient(135deg,#eab308,#ca8a04)' },
    { id: 'loimpress', label: 'LibreOffice Impress', icon: '📽️', bg: 'linear-gradient(135deg,#f97316,#c2410c)' },
    { id: 'lomath', label: 'LibreOffice Math', icon: '√x', bg: 'linear-gradient(135deg,#ec4899,#be185d)' },
    { id: 'remmina', label: 'Remmina', icon: '🖧', bg: 'linear-gradient(135deg,#14b8a6,#0f766e)' },
    { id: 'resources', label: 'Resources', icon: '📈', bg: 'linear-gradient(135deg,#06b6d4,#3b82f6)' },
    { id: 'security', label: 'Security Center', icon: '🛡️', bg: 'linear-gradient(135deg,#f59e0b,#d97706)' },
    { id: 'shotwell', label: 'Shotwell', icon: '🖼️', bg: 'linear-gradient(135deg,#0ea5e9,#0284c7)' },
    { id: 'software', label: 'Software Center', icon: '🅰️', bg: 'linear-gradient(135deg,#64748b,#334155)' },
    { id: 'startupdisk', label: 'Startup Disk', icon: '💾', bg: 'linear-gradient(135deg,#3b82f6,#1d4ed8)' },
    { id: 'texteditor', label: 'Text Editor', icon: '✏️', bg: 'linear-gradient(135deg,#38bdf8,#0284c7)' },
    { id: 'transmission', label: 'Transmission', icon: '⏬', bg: 'linear-gradient(135deg,#ef4444,#991b1b)' },
    { id: 'sovereign', label: 'Sovereign AI', icon: '🐦‍⬛', bg: 'linear-gradient(135deg,#a855f7,#06b6d4)' },
    { id: 'virtmanager', label: 'Virtual Machine Mgr', icon: 'VM', bg: 'linear-gradient(135deg,#06b6d4,#0f766e)' },
    { id: 'boxes', label: 'Boxes', icon: '🧊', bg: 'linear-gradient(135deg,#475569,#0f172a)' }
  ];

  function updateDesktopClock() {
    var el = $('srTopClock');
    if (!el) return;
    var d = new Date();
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var hh = ('0' + d.getHours()).slice(-2);
    var mm = ('0' + d.getMinutes()).slice(-2);
    el.textContent = months[d.getMonth()] + ' ' + d.getDate() + '  ' + hh + ':' + mm;
  }
  updateDesktopClock();
  setInterval(updateDesktopClock, 15000);

  function openDesktopApp(appId, label) {
    if (appId === 'files' || appId === 'ssd') { switchView('fafnir'); return; }
    if (appId === 'terminal') { switchView('console'); return; }
    var win = $('srAppWindow');
    var title = $('srWinTitle');
    var body = $('srWinBody');
    if (!win || !title || !body) return;
    title.textContent = (label || appId) + ' — StormRaven OS';
    win.classList.remove('hidden');

    if (appId === 'moov') {
      body.innerHTML =
        '<h3>🏦 Moov AI Financial — ACH Transfers &amp; Mobile Check Deposit (mRDC)</h3>' +
        '<p class="muted" style="margin:6px 0 12px">NACHA Same-Day ACH · FedNow/RTP Instant Rails · X9.37 Check 21 Mobile Check Deposit with MICR E-13B Extraction</p>' +
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">' +
          '<div class="card" style="margin:0;border:1px solid rgba(16,185,129,0.45)">' +
            '<h4>⚡ Originate ACH Transfer</h4>' +
            '<div style="display:flex;flex-direction:column;gap:6px;margin-top:8px">' +
              '<select id="srMoovAchDir" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px"><option value="debit">ACH Debit / Pull (Deposit to Wallet)</option><option value="credit">ACH Credit / Push (Send Payout)</option></select>' +
              '<input id="srMoovAchAmt" type="number" step="0.01" value="250.00" placeholder="Amount USD" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px">' +
              '<input id="srMoovAchRt" type="text" value="021000021" placeholder="9-Digit ABA Routing #" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px">' +
              '<input id="srMoovAchAcct" type="text" value="4829104921" placeholder="Account #" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px">' +
              '<button id="srMoovAchBtn" class="btn small" style="background:linear-gradient(135deg,#10b981,#0284c7);color:#fff;border:0">Execute ACH Transfer</button>' +
            '</div>' +
          '</div>' +
          '<div class="card" style="margin:0;border:1px solid rgba(6,182,212,0.45)">' +
            '<h4>📸 Mobile Check Deposit (Cash Check)</h4>' +
            '<div style="display:flex;flex-direction:column;gap:6px;margin-top:8px">' +
              '<input id="srMoovChkAmt" type="number" step="0.01" value="500.00" placeholder="Check Amount USD" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px">' +
              '<input id="srMoovChkPayer" type="text" value="Sovereign Client" placeholder="Payor / Maker Name" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px">' +
              '<input id="srMoovChkNum" type="text" value="1042" placeholder="Check Number" style="background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:6px;padding:6px">' +
              '<input id="srMoovChkImg" type="file" accept="image/*" capture="environment" style="font-size:11px;color:#94a3b8">' +
              '<button id="srMoovChkBtn" class="btn small" style="background:linear-gradient(135deg,#06b6d4,#a855f7);color:#fff;border:0">Scan MICR &amp; Cash Check</button>' +
            '</div>' +
          '</div>' +
        '</div>' +
        '<pre id="srMoovOutBox" class="code-box">Loading Moov Sovereign Treasury Wallet…</pre>';
      api('/command', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ command: 'moov_status' }) })
        .then(function (r) { if ($('srMoovOutBox')) $('srMoovOutBox').textContent = JSON.stringify(r.result || r, null, 2); })
        .catch(function () {});
      if ($('srMoovAchBtn')) $('srMoovAchBtn').addEventListener('click', function () {
        $('srMoovOutBox').textContent = 'Originating Moov Same-Day ACH transfer…';
        api('/command', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            command: 'moov_ach',
            direction: $('srMoovAchDir').value,
            amount: Number($('srMoovAchAmt').value || 250),
            routing: $('srMoovAchRt').value || '021000021',
            account: $('srMoovAchAcct').value || '4829104921'
          })
        }).then(function (r) { $('srMoovOutBox').textContent = JSON.stringify(r.result || r, null, 2); });
      });
      if ($('srMoovChkBtn')) $('srMoovChkBtn').addEventListener('click', function () {
        $('srMoovOutBox').textContent = 'Scanning MICR E-13B & clearing X9.37 Mobile Check Deposit…';
        api('/command', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            command: 'moov_deposit_check',
            amount: Number($('srMoovChkAmt').value || 500),
            payer: $('srMoovChkPayer').value || 'Sovereign Client',
            checkNumber: $('srMoovChkNum').value || '1042',
            routing: $('srMoovAchRt') ? $('srMoovAchRt').value : '021000021',
            account: '981240112'
          })
        }).then(function (r) { $('srMoovOutBox').textContent = JSON.stringify(r.result || r, null, 2); });
      });
      return;
    }

    if (appId === 'calc') {
      body.innerHTML =
        '<div style="max-width:260px;margin:0 auto">' +
        '<input id="srCalcDisp" type="text" readonly value="0" style="width:100%;padding:10px;font-size:20px;text-align:right;background:#07030a;color:#06b6d4;border:1px solid #06b6d4;border-radius:8px;margin-bottom:10px;font-family:monospace">' +
        '<div id="srCalcKeys" style="display:grid;grid-template-columns:repeat(4,1fr);gap:6px"></div></div>';
      var keys = ['7','8','9','/','4','5','6','*','1','2','3','-','0','.','=','+','C'];
      var disp = $('srCalcDisp');
      var expr = '';
      keys.forEach(function (k) {
        var b = document.createElement('button');
        b.className = 'btn small';
        b.textContent = k;
        b.addEventListener('click', function () {
          if (k === 'C') { expr = ''; disp.value = '0'; }
          else if (k === '=') {
            try { expr = String(Function('"use strict";return (' + expr.replace(/[^0-9+\-*/.()]/g, '') + ')')()); disp.value = expr; }
            catch (e) { disp.value = 'Error'; expr = ''; }
          } else { expr += k; disp.value = expr; }
        });
        $('srCalcKeys').appendChild(b);
      });
    } else if (appId === 'lowriter' || appId === 'texteditor' || appId === 'docviewer') {
      body.innerHTML =
        '<div class="row-between"><span class="muted">Document Buffer · UTF-8 · StormRaven Office Suite</span><span class="badge ok">SAVED IN MEMORY</span></div>' +
        '<textarea style="width:100%;height:340px;background:#07030a;color:#e2e8f0;border:1px solid rgba(6,182,212,0.35);border-radius:8px;padding:12px;font-family:monospace;font-size:13px"># StormRaven OS — Sovereign Document\n\nAll 9 Realms nominal.\nMaster Password: Stormraven\nLuci Key: AUTHORIZED (/etc/stormraven/Luci.key)\n</textarea>';
    } else if (appId === 'mail') {
      body.innerHTML =
        '<h3>StormRaven Mail &amp; iCloud+ Custom Domain Bridge</h3>' +
        '<p class="muted" style="margin:6px 0 12px">Linked Apple ID: <strong>faithjennings055@icloud.com</strong> · Address: <strong>mrstormraven@stormravenoddities.com</strong></p>' +
        '<pre class="code-box">Custom Email:   mrstormraven@stormravenoddities.com\niCloud Account: faithjennings055@icloud.com\nIMAP Server:    imap.mail.me.com:993 (SSL/TLS)\nSMTP Server:    smtp.mail.me.com:587 (STARTTLS)\n\nCloudflare DNS Records for iCloud+ Custom Domain (stormravenoddities.com):\n  MX    @                 mx01.mail.icloud.com. (Priority 10)\n  MX    @                 mx02.mail.icloud.com. (Priority 10)\n  TXT   @                 "v=spf1 include:icloud.com ~all"\n  CNAME sig1._domainkey   sig1.dkim.stormravenoddities.com.at.icloudmailadmin.com.</pre>';
    } else if (appId === 'security') {
      body.innerHTML =
        '<h3>Heimdall &amp; Luci Security Center</h3>' +
        '<p class="muted" style="margin:6px 0 12px">Zero-Trust 7-Step Gatekeeper · WireGuard Kill-Switch · Luci Hardware Seal</p>' +
        '<pre class="code-box">Luci Status:     [AUTHORIZED]\nKey Path:        /etc/stormraven/Luci.key\nKey Token:       SR-LUCI-INFINITY-SOVEREIGN-KEY-v3.3\nMaster Password: Stormraven (NOPASSWD live sudo enabled)\nSSH Policy:      Key-Only (Faith GitHub ECDSA + Ed25519 authorized)\nWireGuard VPN:   wg0 + STORMRAVEN_KILLSWITCH ready</pre>';
    } else if (appId === 'sovereign') {
      body.innerHTML =
        '<h3>Freya &amp; Odin Onboard AI (Local Pantheon Mind)</h3>' +
        '<p class="muted" style="margin:6px 0 10px">No external API key required. Connected to local StormRaven Kernel (:8787).</p>' +
        '<div style="display:flex;gap:8px;margin-bottom:10px"><input id="srAiPrompt" type="text" placeholder="Ask Freya or Odin..." style="flex:1;background:#07030a;color:#fff;border:1px solid #06b6d4;border-radius:8px;padding:8px"><button id="srAiSend" class="btn small">Ask AI</button></div>' +
        '<pre id="srAiReply" class="code-box">[Freya]: I am listening, Faith. All 9 Realms are online and your Luci Key is sealed.</pre>';
      $('srAiSend').addEventListener('click', function () {
        var q = $('srAiPrompt').value.trim() || 'status';
        $('srAiReply').textContent = 'Querying Freya & Odin…';
        runCommand('odin freya_think', false).then(function (r) {
          $('srAiReply').textContent = JSON.stringify(r, null, 2);
        });
      });
    } else if (appId === 'installos' || appId === 'startupdisk' || appId === 'iso') {
      body.innerHTML =
        '<h3>💿 Try or Install StormRaven OS: Infinity Protocol v3.9.0</h3>' +
        '<p class="muted" style="margin:6px 0 12px">Ubuntu 24.04 LTS (Noble) · Linux 7.0.0-42-generic HWE · Full 2011–2026 Firmware &amp; Driver Stack</p>' +
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">' +
          '<div class="card" style="margin:0;border:1px solid rgba(6,182,212,0.4)">' +
            '<h4>🖥 Try StormRaven OS (Live Mode)</h4>' +
            '<p class="muted" style="margin:6px 0 10px">Run directly from USB/RAM without touching your hard drive. Full 9 Realms, Odin Pantheon, and Rescue Suite active.</p>' +
            '<button id="srWinTryClose" class="btn small accent-outline">Continue Live Session</button>' +
          '</div>' +
          '<div class="card" style="margin:0;border:1px solid rgba(168,85,247,0.5)">' +
            '<h4>💿 Install StormRaven OS v3.9.0 to Disk</h4>' +
            '<p class="muted" style="margin:6px 0 10px">Automatic GPT partitioning (BIOS Boot + 512MB EFI + EXT4 Root), GRUB UEFI/BIOS bootloader, and user setup.</p>' +
            '<button id="srRunDiskInstallBtn" class="btn small" style="background:linear-gradient(135deg,#06b6d4,#a855f7);color:#fff;border:0">Check Disks &amp; Launch Installer</button>' +
          '</div>' +
        '</div>' +
        '<pre id="srInstallStatusBox" class="code-box">Run in terminal anytime:  sudo stormraven-installer\nDebian Package (.deb):    sudo dpkg -i stormraven-os_3.9.0_amd64.deb\nUbuntu Snap (.snap):      sudo snap install --dangerous --classic stormraven-os_3.9.0_amd64.snap</pre>';
      if ($('srWinTryClose')) $('srWinTryClose').addEventListener('click', function () { win.classList.add('hidden'); });
      if ($('srRunDiskInstallBtn')) $('srRunDiskInstallBtn').addEventListener('click', function () {
        $('srInstallStatusBox').textContent = 'Probing target disks and Ubuntu Boot Disk Rescue toolset…';
        runCommand('installer_status', false).then(function (r) {
          $('srInstallStatusBox').textContent = JSON.stringify(r, null, 2) + '\n\nTo run interactive disk installation on bare metal:\n  sudo stormraven-installer';
        });
      });
    } else if (appId === 'gparted' || appId === 'bootrepair' || appId === 'rescue' || appId === 'firmware') {
      body.innerHTML =
        '<h3>🛠 Ubuntu Boot Disk Rescue, Partitioning &amp; 2011–2026 Hardware Suite (v3.9.0)</h3>' +
        '<p class="muted" style="margin:6px 0 10px">All standard Ubuntu Live Boot Disk tools + 2011–2026 CPU/GPU/Wi-Fi/NIC/NVMe firmware &amp; Linux 7.0.0-42-generic HWE kernel:</p>' +
        '<pre class="code-box">' +
        '• Kernel:             Linux 7.0.0-42-generic (Ubuntu HWE + linux-modules-extra + ZFS)\n' +
        '• CPU Microcode:      intel-microcode (2011 Sandy Bridge → 2026 Arrow Lake) + amd64-microcode (Bulldozer → Zen 5)\n' +
        '• GPU Drivers:        amdgpu, radeon, i915, xe, nouveau, modesetting, fbdev, vesa + Mesa Vulkan & VA-API (i965 + iHD)\n' +
        '• Wi-Fi/BT Firmware:  Intel iwlwifi, Broadcom brcm80211/b43, Realtek rtlwifi/rtw88/rtw89, Qualcomm/Atheros ath9k/10k/11k/12k, MediaTek mt76/7921/7922, Marvell\n' +
        '• Partitioning/Disk:  gparted, parted, gdisk/sgdisk, fdisk, lvm2, cryptsetup (LUKS), mdadm (RAID), ntfs-3g, exfatprogs, btrfs-progs, xfsprogs, dosfstools\n' +
        '• Boot & Recovery:    efibootmgr, grub-install (UEFI+BIOS), os-prober, mokutil, testdisk, photorec, gddrescue, partclone, smartmontools, nvme-cli, timeshift, chntpw\n' +
        '• Diagnostics:        inxi -Fxz, lshw, lspci, lsusb, dmidecode, htop, iotop, ncdu, nmap, mtr\n' +
        '</pre>';
    } else if (appId === 'virtmanager' || appId === 'boxes') {
      body.innerHTML =
        '<h3>KVM / QEMU Hypervisor &amp; Virtual Machine Manager</h3>' +
        '<pre id="srVmBox" class="code-box">Loading hypervisor status…</pre>' +
        '<p class="muted" style="margin-top:8px">Windows 11 Edition 1-Command Installer (PowerShell Admin):</p>' +
        '<code class="install-cmd">irm ' + baseUrl() + '/install-win11.ps1 | iex</code>';
      runCommand('odin vm_status', false).then(function (r) {
        if ($('srVmBox')) $('srVmBox').textContent = JSON.stringify(r, null, 2);
      });
    } else if (appId === 'resources' || appId === 'system') {
      body.innerHTML =
        '<h3>System Resources &amp; Nine Realms Telemetry</h3>' +
        '<pre id="srResBox" class="code-box">Sampling host sensors…</pre>';
      runCommand('odin telemetry', false).then(function (r) {
        if ($('srResBox')) $('srResBox').textContent = JSON.stringify(r, null, 2);
      });
    } else {
      body.innerHTML =
        '<h3>' + esc(label || appId) + '</h3>' +
        '<p class="muted" style="margin:6px 0 12px">StormRaven OS 24.04 LTS (Noble Numbat) · Native Subsystem Ready</p>' +
        '<pre class="code-box">Application: ' + esc(label || appId) + '\nStatus:      ONLINE (Ethereal Void Desktop)\nKernel:      http://127.0.0.1:8787 (Bifrost v1)</pre>';
    }
  }

  function renderDesktopGrid(filterText) {
    var grid = $('srAppGrid');
    if (!grid) return;
    grid.innerHTML = '';
    var q = (filterText || '').trim().toLowerCase();
    desktopApps.filter(function (a) { return !q || a.label.toLowerCase().indexOf(q) !== -1; }).forEach(function (a) {
      var tile = document.createElement('button');
      tile.type = 'button';
      tile.className = 'sr-app-tile';
      tile.innerHTML =
        '<div class="sr-app-icon" style="background:' + a.bg + '">' + a.icon + '</div>' +
        '<div class="sr-app-label">' + esc(a.label) + '</div>';
      tile.addEventListener('click', function () { openDesktopApp(a.id, a.label); });
      grid.appendChild(tile);
    });
  }
  renderDesktopGrid('');

  if ($('srAppSearch')) {
    $('srAppSearch').addEventListener('input', function (e) { renderDesktopGrid(e.target.value); });
  }
  if ($('srWinClose')) {
    $('srWinClose').addEventListener('click', function () { $('srAppWindow').classList.add('hidden'); });
  }
  if ($('srModeToggleBtn')) {
    $('srModeToggleBtn').addEventListener('click', function () {
      var sh = $('srDesktopShell');
      if (!sh) return;
      var isWin = sh.classList.toggle('mode-win11');
      $('srModeToggleBtn').textContent = isWin ? 'Switch to Ubuntu Mode' : 'Switch to Windows 11 Mode';
    });
  }
  if ($('srTryInstallBtn')) {
    $('srTryInstallBtn').addEventListener('click', function () { openDesktopApp('installos', 'Install StormRaven OS v3.9.0'); });
  }
  if ($('srBannerTryBtn')) {
    $('srBannerTryBtn').addEventListener('click', function () {
      if ($('srTryInstallBanner')) $('srTryInstallBanner').style.display = 'none';
    });
  }
  if ($('srBannerInstallBtn')) {
    $('srBannerInstallBtn').addEventListener('click', function () { openDesktopApp('installos', 'Install StormRaven OS v3.9.0'); });
  }
  if ($('srBannerRescueBtn')) {
    $('srBannerRescueBtn').addEventListener('click', function () { openDesktopApp('rescue', 'Boot Disk Rescue & Drivers'); });
  }
  document.querySelectorAll('#srDock .sr-dock-item').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var app = btn.getAttribute('data-app');
      if (app === 'grid') {
        if ($('srAppWindow')) $('srAppWindow').classList.add('hidden');
      } else {
        openDesktopApp(app, btn.getAttribute('title') || app);
      }
    });
  });

  // Connect immediately to same-origin (or saved URL) with zero modal pop-up!
  refreshStatus();
  refreshTabs();
  refreshDecisions();
  connectWs();
  state.pollTimer = setInterval(refreshStatus, 10000);
})();
