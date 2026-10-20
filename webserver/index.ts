// Your public webserver. Runs on port 3001; the platform routes external
// traffic from your public skydive URL to this port. Supervisor starts it on
// every boot via ../webserver.sh (see that file), so this listener is always
// live.
//
// Out of the box it serves one thing: a default page at `/` (see landing.ts)
// that says who hosts this URL and links every route you list below. Add your
// routes to `routes`. Register a `GET /` route to replace the default page.
//
// This is where interactive web apps, dashboards, forms, landing pages, and
// inbound webhooks / OAuth callbacks belong.
//
// WHERE TO BUILD WHAT (read this before creating files):
//   - A web app / website / page the user opens in a browser: ROUTES IN THIS
//     FILE (webserver/index.ts). Do NOT create a second server or edit the
//     harness's own /home/user/.self/index.ts — that file is the agent
//     runtime, not your canvas, and hacking into it breaks the runtime.
//   - A downloadable artifact (report, CSV, image, PDF, doc): generate it,
//     save under ~/Documents/, and share it via the channel — do not serve
//     it from here unless it's part of a live page.
//   - State for any of the above: a `platform db` Postgres (see below),
//     never local disk.
//
// Notes for when you build on this:
//   - Keep state (dedupe sets, queues) in a `platform db` Postgres, NOT on
//     local disk and NOT in ~/Documents (a hard NFS mount — a stalled write
//     parks the request handler in uninterruptible sleep and the server stops
//     answering while still holding the port).
//   - Verify a webhook's signature before trusting its body; return a fast 2xx;
//     hand slow work to a background task or a `platform automation` firing.
//   - Set the HTML <title> on any page you serve — it becomes the tab name in
//     the user's chat UI.
//   - Reload after editing: `supervisorctl restart webserver` (NEVER restart
//     the harness — that kills your in-flight agent run).
//
// Common traps (real agents have burned minutes on these):
//   - This file imports with node ESM, so any package you `import` must exist
//     under /home/user/.self/node_modules (npm i <pkg> in /home/user/.self).
//     The template preinstalls express AND pg, so a database-backed app works
//     with no install step; anything else, install before the first restart.
//     Verify with `node --input-type=module -e "import '<pkg>'"` first.
//   - The webserver is auto-started on boot once webserver.sh exists, so
//     `supervisorctl start webserver` says "already started" — use
//     `restart` after edits.
//   - With `platform secrets run` wrapping the exec, a cold restart takes a
//     few seconds. `curl -m 5 localhost:3001/health` a beat after the
//     restart; a 000 right away usually means the server is still booting.
//   - Tail webserver.log AFTER the restart, not before — old crash lines
//     from a previous attempt will still be in there and will mislead you.
import http from 'node:http';
import { DEFAULT_PAGE_HEADER, renderLandingPage } from './landing.ts';

// oxlint-disable-next-line eslint-plugin-node/no-process-env -- startup config; no env loader in this workspace
const PORT = Number(process.env.WEBSERVER_PORT ?? 3001);

type Route = {
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  handler: (
    req: http.IncomingMessage,
    res: http.ServerResponse
  ) => void | Promise<void>;
  /** Shown next to the path on the default page. */
  label?: string;
  /** GET routes appear on the default page unless this is false. */
  listed?: boolean;
};

const routes: Route[] = [
  // Liveness probe. Keep this so supervisor's :3001 listener is verifiable
  // (`curl -s localhost:3001/health`) even before you add real routes.
  {
    method: 'GET',
    path: '/health',
    listed: false,
    handler: (_req, res) => {
      res.writeHead(200, { 'content-type': 'text/plain' });
      res.end('ok');
    },
  },
  // Add your routes here, e.g.:
  // {
  //   method: 'GET',
  //   path: '/dashboard',
  //   label: 'Dashboard',
  //   handler: (_req, res) => {
  //     res.writeHead(200, { 'content-type': 'text/html' });
  //     res.end('<!DOCTYPE html><title>Dashboard</title><h1>Hello</h1>');
  //   },
  // },
];

const server = http.createServer(async (req, res) => {
  try {
    const path = new URL(req.url ?? '/', 'http://localhost').pathname;
    // Node omits the body on HEAD responses, so GET handlers answer HEAD too.
    const method = req.method === 'HEAD' ? 'GET' : req.method;
    const route = routes.find((r) => r.method === method && r.path === path);
    if (route) {
      await route.handler(req, res);
      return;
    }

    if (method === 'GET' && path === '/') {
      const links = routes
        .filter(
          (r) => r.method === 'GET' && r.path !== '/' && r.listed !== false
        )
        .map((r) => ({ path: r.path, label: r.label }));
      res.writeHead(200, {
        'content-type': 'text/html; charset=utf-8',
        [DEFAULT_PAGE_HEADER]: '1',
      });
      res.end(await renderLandingPage(links));
      return;
    }

    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('Not found');
  } catch (error) {
    // oxlint-disable-next-line eslint/no-console -- thin shell; no logger dependency here
    console.error('[webserver] request failed', error);
    if (!res.headersSent) res.writeHead(500, { 'content-type': 'text/plain' });
    res.end('Internal error');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  // oxlint-disable-next-line eslint/no-console -- thin shell; no logger dependency here
  console.log(`[webserver] listening on :${PORT}`);
});
