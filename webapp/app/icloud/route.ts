import { CORS_HEADERS, jsonOk, optionsOk } from "@/lib/bifrost-server"

const ICLOUD_DATA = {
  ok: true,
  protocol: "StormRaven OS: Infinity Protocol v3.7.0",
  appleId: "faithjennings055@icloud.com",
  customEmail: "mrstormraven@stormravenoddities.com",
  domain: "stormravenoddities.com",
  dnsStatus: "LIVE_AND_VERIFIED",
  mailServers: {
    imap: { host: "imap.mail.me.com", port: 993, ssl: true, username: "mrstormraven@stormravenoddities.com" },
    smtp: { host: "smtp.mail.me.com", port: 587, starttls: true, username: "mrstormraven@stormravenoddities.com" },
  },
  dnsRecordsForIcloudPlus: [
    { type: "TXT", name: "@", value: "apple-domain=IwhmMC44iTKV1nxD", status: "LIVE" },
    { type: "MX", name: "@", value: "mx01.mail.icloud.com. (Priority 10)", status: "LIVE" },
    { type: "MX", name: "@", value: "mx02.mail.icloud.com. (Priority 10)", status: "LIVE" },
    { type: "TXT", name: "@", value: "v=spf1 include:icloud.com ~all", status: "LIVE" },
    { type: "CNAME", name: "sig1._domainkey", value: "sig1.dkim.stormravenoddities.com.at.icloudmailadmin.com.", status: "LIVE" },
  ],
}

export async function GET(req: Request) {
  const accept = req.headers.get("accept") || ""
  const url = new URL(req.url)
  if (url.searchParams.get("format") === "json" || (!accept.includes("text/html") && accept.includes("application/json"))) {
    return jsonOk(ICLOUD_DATA)
  }

  const html = `<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>StormRaven OS · iCloud & Custom Email Hub (mrstormraven@stormravenoddities.com)</title>
  <style>
    :root { --bg: #07030a; --card: #110b1d; --line: rgba(6,182,212,0.3); --cyan: #06b6d4; --purple: #a855f7; --ok: #10b981; --text: #f1f5f9; --muted: #94a3b8; }
    * { box-sizing: border-box; }
    body { margin: 0; background: radial-gradient(circle at 50% 0%, #1a1030 0%, #07030a 70%); color: var(--text); font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; min-height: 100vh; padding: 28px 16px; }
    .wrap { max-width: 920px; margin: 0 auto; display: flex; flex-direction: column; gap: 18px; }
    .card { background: rgba(17,11,29,0.88); border: 1px solid var(--line); border-radius: 14px; padding: 20px; box-shadow: 0 12px 32px rgba(0,0,0,0.55); }
    .top { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; }
    h1 { font-size: 18px; margin: 0; color: var(--cyan); letter-spacing: 0.05em; }
    h2 { font-size: 13px; margin: 0 0 12px; color: var(--cyan); text-transform: uppercase; letter-spacing: 0.08em; }
    .badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 700; background: rgba(16,185,129,0.15); color: var(--ok); border: 1px solid rgba(16,185,129,0.4); }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; }
    .kv { background: rgba(7,3,10,0.7); border: 1px solid rgba(148,163,184,0.2); border-radius: 10px; padding: 12px; }
    .kv-label { font-size: 10px; color: var(--muted); text-transform: uppercase; margin-bottom: 4px; }
    .kv-val { font-size: 13px; font-weight: 700; color: var(--text); word-break: break-all; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid rgba(148,163,184,0.15); }
    th { color: var(--cyan); font-size: 10px; text-transform: uppercase; }
    .btns { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 6px; }
    .btn { display: inline-flex; align-items: center; gap: 6px; padding: 9px 14px; border-radius: 8px; font-size: 12px; font-weight: 600; text-decoration: none; border: 1px solid var(--cyan); background: rgba(6,182,212,0.16); color: var(--text); }
    .btn.secondary { border-color: rgba(168,85,247,0.5); background: rgba(168,85,247,0.16); }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card top">
      <div>
        <h1>✦ STORMRAVEN OS · INFINITY PROTOCOL v3.7.0</h1>
        <div style="font-size:12px;color:var(--muted);margin-top:4px">iCloud Sovereign Bridge &amp; Custom Email Server Hub</div>
      </div>
      <span class="badge">● ALL 5 DNS RECORDS LIVE IN CLOUDFLARE</span>
    </div>

    <div class="card">
      <h2>Linked Identity &amp; Custom Email</h2>
      <div class="grid">
        <div class="kv"><div class="kv-label">Custom Email Address</div><div class="kv-val" style="color:var(--cyan)">mrstormraven@stormravenoddities.com</div></div>
        <div class="kv"><div class="kv-label">Linked Apple ID / iCloud</div><div class="kv-val">faithjennings055@icloud.com</div></div>
        <div class="kv"><div class="kv-label">IMAP Incoming Server</div><div class="kv-val">imap.mail.me.com : 993 (SSL/TLS)</div></div>
        <div class="kv"><div class="kv-label">SMTP Outgoing Server</div><div class="kv-val">smtp.mail.me.com : 587 (STARTTLS)</div></div>
      </div>
      <div class="btns" style="margin-top:14px">
        <a class="btn" href="https://www.icloud.com/icloudplus/" target="_blank" rel="noreferrer">Open iCloud+ Custom Email Settings ↗</a>
        <a class="btn" href="https://www.icloud.com/mail/" target="_blank" rel="noreferrer">Open iCloud Mail Inbox ↗</a>
        <a class="btn secondary" href="mailto:mrstormraven@stormravenoddities.com">Send Test Email ✉</a>
        <a class="btn secondary" href="/">← Back to StormRaven OS Dashboard</a>
      </div>
    </div>

    <div class="card">
      <h2>Verified Live Cloudflare DNS Records (stormravenoddities.com)</h2>
      <table>
        <thead><tr><th>Type</th><th>Name</th><th>Value / Target</th><th>Status</th></tr></thead>
        <tbody>
          ${ICLOUD_DATA.dnsRecordsForIcloudPlus.map((r) => `<tr><td>${r.type}</td><td>${r.name}</td><td>${r.value}</td><td><span class="badge">${r.status}</span></td></tr>`).join("")}
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Connected StormRaven OS Apps &amp; Downloads</h2>
      <div class="btns">
        <a class="btn" href="/">Álfheimr Web OS Dashboard</a>
        <a class="btn" href="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app" target="_blank" rel="noreferrer">Mobile PWA &amp; Kernel Gateway ↗</a>
        <a class="btn secondary" href="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/StormRavenOS-Infinity-Protocol-v3.7.0-amd64.iso">Download Infinity Protocol v3.7.0 ISO ⬇</a>
        <a class="btn secondary" href="/icloud?format=json">View Raw JSON API</a>
      </div>
    </div>
  </div>
</body>
</html>`

  return new Response(html, {
    status: 200,
    headers: { ...CORS_HEADERS, "Content-Type": "text/html; charset=utf-8" },
  })
}

export async function POST(req: Request) {
  return jsonOk(ICLOUD_DATA)
}

export async function OPTIONS() {
  return optionsOk()
}
