import { jsonOk, optionsOk } from "@/lib/bifrost-server"
export async function GET() {
  return jsonOk({
    ok: true,
    protocol: "StormRaven OS: Infinity Protocol v3.7.0",
    appleId: "faithjennings055@icloud.com",
    customEmail: "mrstormraven@stormravenoddities.com",
    domain: "stormravenoddities.com",
    mailServers: {
      imap: { host: "imap.mail.me.com", port: 993, ssl: true, username: "mrstormraven@stormravenoddities.com" },
      smtp: { host: "smtp.mail.me.com", port: 587, starttls: true, username: "mrstormraven@stormravenoddities.com" },
    },
    dnsRecordsForIcloudPlus: [
      { type: "MX", name: "@", value: "mx01.mail.icloud.com.", priority: 10 },
      { type: "MX", name: "@", value: "mx02.mail.icloud.com.", priority: 10 },
      { type: "TXT", name: "@", value: "v=spf1 include:icloud.com ~all" },
      { type: "CNAME", name: "sig1._domainkey", value: "sig1.dkim.stormravenoddities.com.at.icloudmailadmin.com." },
    ],
  })
}
export async function POST() { return GET() }
export async function OPTIONS() { return optionsOk() }
