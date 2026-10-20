// The default page served at the root of your public URL until you replace it.
// It says who hosts the URL and links every listed GET route from index.ts, so
// a visitor who lands on the bare domain still finds your pages.
//
// To serve your own root page, register a `GET /` route in index.ts. To drop
// this page entirely, delete this file and its import in index.ts.

// oxlint-disable-next-line eslint-plugin-node/no-process-env -- startup config; no env loader in this workspace
const API_URL = process.env.SKYDIVE_API_URL;
const NAME_TTL_MS = 5 * 60 * 1000;

// Lets the platform tell this placeholder apart from a page you built, so the
// chat UI does not open a webserver tab for it.
export const DEFAULT_PAGE_HEADER = 'x-skydive-default-page';

export type LandingLink = { path: string; label?: string };

let cachedName: { value: string | null; at: number } | null = null;

/**
 * The sandbox egress proxy authenticates requests to the platform API, so this
 * call needs no token. Cached so a page view never waits on the API twice, and
 * refreshed so a rename shows up within minutes.
 */
async function agentName(): Promise<string | null> {
  if (cachedName && Date.now() - cachedName.at < NAME_TTL_MS) {
    return cachedName.value;
  }
  let value: string | null = cachedName?.value ?? null;
  if (API_URL) {
    try {
      const res = await fetch(`${API_URL}/api/v1/sdk/agents/me`, {
        signal: AbortSignal.timeout(2000),
      });
      if (res.ok) {
        const body: unknown = await res.json();
        const agent =
          typeof body === 'object' && body !== null && 'agent' in body
            ? body.agent
            : null;
        const name =
          typeof agent === 'object' && agent !== null && 'name' in agent
            ? agent.name
            : null;
        if (typeof name === 'string' && name.trim()) value = name.trim();
      }
    } catch (_error) {
      // Best effort: render the page without a name rather than fail it.
    }
  }
  cachedName = { value, at: Date.now() };
  return value;
}

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

const LOGO_SVG = `<svg aria-hidden="true" viewBox="0 0 624 569" width="44" height="40"><path d="M514.152 186.195C518.119 182.447 523.5 180.464 528.94 180.931C582.067 185.408 623.79 229.945 623.79 284.225C623.79 338.504 582.067 383.056 528.94 387.519C523.5 387.971 518.134 386.002 514.152 382.254C497.44 366.49 449.825 321.544 425.296 298.385C417.144 290.685 417.158 277.735 425.296 270.035L514.138 186.181L514.152 186.195Z" fill="#DF9FB7"/><path d="M109.638 186.195C105.671 182.447 100.29 180.464 94.8504 180.931C41.7231 185.408 0 229.945 0 284.225C0 338.504 41.7231 383.056 94.8504 387.519C100.29 387.971 105.657 386.002 109.638 382.254C126.35 366.49 173.965 321.544 198.495 298.385C206.647 290.685 206.632 277.735 198.495 270.035L109.652 186.181L109.638 186.195Z" fill="#E16566"/><path d="M498.562 410.709C503.783 412.284 508.158 415.959 510.477 420.888C533.096 469.174 515.275 527.551 468.214 554.618C421.154 581.67 361.756 567.714 331.393 523.891C328.272 519.399 327.31 513.741 328.593 508.418L357.191 389.49C359.816 378.597 371.045 372.136 381.779 375.388C414.037 385.145 476.629 404.059 498.577 410.709H498.562Z" fill="#EFB045"/><path d="M296.057 60.035C297.34 54.712 296.378 49.054 293.257 44.562C262.895 0.739 203.496 -13.217 156.436 13.835C109.375 40.902 91.554 99.279 114.173 147.579C116.492 152.508 120.852 156.183 126.059 157.758C147.992 164.409 210.555 183.396 242.813 193.182C253.547 196.434 264.79 189.988 267.415 179.079L296.057 60.05V60.035Z" fill="#6699C4"/><path d="M126.103 410.706C120.867 412.281 116.478 415.956 114.159 420.9C91.555 469.186 109.376 527.563 156.436 554.615C203.497 581.667 262.895 567.711 293.257 523.888C296.378 519.382 297.341 513.723 296.057 508.4L267.43 389.662C264.805 378.783 253.576 372.337 242.857 375.56L126.117 410.692L126.103 410.706Z" fill="#48A478"/><path d="M328.564 60.005C327.295 54.697 328.257 49.053 331.364 44.561C361.726 0.724 421.139 -13.247 468.2 13.819C515.275 40.886 533.081 99.278 510.462 147.564C508.158 152.493 503.798 156.153 498.591 157.743C476.643 164.422 413.949 183.497 381.618 193.326C370.87 196.593 359.597 190.118 356.987 179.195L328.564 60.005Z" fill="#E07B30"/></svg>`;

const ARROW_SVG = `<svg aria-hidden="true" viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3.5 10.5 8 6 12.5"/></svg>`;

export async function renderLandingPage(links: LandingLink[]): Promise<string> {
  const name = await agentName();
  const host = name ? `<strong>${escapeHtml(name)}</strong>` : 'an agent';
  const title = name ? `${escapeHtml(name)} · Skydive` : 'Skydive';

  const list =
    links.length === 0
      ? `<div class="empty"><p class="empty-title">Nothing here yet</p><p class="empty-body">Pages ${name ? escapeHtml(name) : 'this agent'} publishes will show up here.</p></div>`
      : `<ul class="links">${links
          .map(
            (l) =>
              `<li><a href="${escapeHtml(l.path)}">${
                l.label
                  ? `<span class="label">${escapeHtml(l.label)}</span>`
                  : ''
              }<span class="path">${escapeHtml(l.path)}</span><span class="arrow">${ARROW_SVG}</span></a></li>`
          )
          .join('')}</ul>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="color-scheme" content="light dark" />
<title>${title}</title>
<style>
  :root {
    --bg-page: #f7f7f7;
    --surface-card: #ffffff;
    --border: #ebebe9;
    --border-dashed: #ddd9d2;
    --row-hover: #fafafa;
    --text-primary: #262523;
    --text-secondary: #5c5c5c;
    --text-muted: #8f8d88;
    --shadow: 0 1px 2px rgb(38 37 35 / 0.04), 0 8px 24px rgb(38 37 35 / 0.05);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg-page: #101010;
      --surface-card: #191919;
      --border: #2e2e2e;
      --border-dashed: #3d3d3d;
      --row-hover: #202020;
      --text-primary: #f5f5f5;
      --text-secondary: #acacac;
      --text-muted: #8f8f8f;
      --shadow: none;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 48px 16px;
    background: var(--bg-page);
    color: var(--text-primary);
    font-family: "Inter", ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  main { width: 100%; max-width: 440px; display: flex; flex-direction: column; align-items: center; gap: 32px; }
  header { display: flex; flex-direction: column; align-items: center; gap: 20px; text-align: center; }
  h1 {
    margin: 0;
    font-family: "Aeonik", "Inter", ui-sans-serif, system-ui, -apple-system, sans-serif;
    font-size: 24px;
    line-height: 32px;
    font-weight: 400;
    letter-spacing: -0.01em;
    color: var(--text-secondary);
  }
  h1 strong { font-weight: 500; color: var(--text-primary); }
  h1 a {
    color: var(--text-primary);
    font-weight: 500;
    text-decoration: underline;
    text-decoration-color: var(--border-dashed);
    text-underline-offset: 4px;
    text-decoration-thickness: 1.5px;
    transition: text-decoration-color 120ms ease;
  }
  h1 a:hover { text-decoration-color: currentColor; }
  section { width: 100%; display: flex; flex-direction: column; gap: 10px; }
  .eyebrow { margin: 0 4px; font-size: 13px; line-height: 16px; font-weight: 500; color: var(--text-muted); }
  .links {
    list-style: none;
    margin: 0;
    padding: 4px;
    background: var(--surface-card);
    border: 1px solid var(--border);
    border-radius: 16px;
    box-shadow: var(--shadow);
  }
  .links a {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 12px 12px 14px;
    border-radius: 12px;
    color: var(--text-primary);
    text-decoration: none;
    transition: background 120ms ease;
  }
  .links a:hover { background: var(--row-hover); }
  .label { font-size: 14px; line-height: 20px; font-weight: 500; white-space: nowrap; }
  .path {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
    font-size: 13px;
    line-height: 20px;
    color: var(--text-secondary);
  }
  .label + .path { color: var(--text-muted); }
  .arrow { display: flex; color: var(--text-muted); transition: transform 120ms ease, color 120ms ease; }
  .links a:hover .arrow { color: var(--text-primary); transform: translateX(2px); }
  .empty {
    padding: 28px 24px;
    text-align: center;
    border: 1px dashed var(--border-dashed);
    border-radius: 16px;
  }
  .empty p { margin: 0; }
  .empty-title { font-size: 14px; line-height: 20px; font-weight: 500; color: var(--text-primary); }
  .empty-body { margin-top: 4px !important; font-size: 14px; line-height: 20px; color: var(--text-muted); }
</style>
</head>
<body>
<main>
  <header>
    ${LOGO_SVG}
    <h1>Hosted by ${host} on <a href="https://skydive.com">Skydive</a></h1>
  </header>
  <section>
    ${links.length === 0 ? '' : '<p class="eyebrow">Pages</p>'}
    ${list}
  </section>
</main>
</body>
</html>`;
}
