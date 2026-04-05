const http = require('http');
const net = require('net');

const PORT = parseInt(process.env.PORT || '8080');
const OS = process.platform === 'win32' ? 'Windows' : 'Linux';

const CHECKS = [
  {
    name: 'MSSQL',
    fn: () => tcpProbe(process.env.SQL_HOST, parseInt(process.env.SQL_PORT || '1433')),
  },
  {
    name: 'Service Bus (AMQP)',
    fn: () => tcpProbe(process.env.SB_HOST, parseInt(process.env.SB_PORT || '5672')),
  },
  {
    name: 'Azure Storage (Blob)',
    fn: () => httpProbe(process.env.STORAGE_URL),
  },
  {
    name: `Peer Service (${OS === 'Windows' ? 'Linux' : 'Windows'})`,
    fn: () => httpProbe(process.env.PEER_URL),
  },
];

function tcpProbe(host, port, timeout = 3000) {
  return new Promise((resolve) => {
    if (!host) return resolve({ ok: false, detail: 'not configured' });
    const sock = new net.Socket();
    sock.setTimeout(timeout);
    sock.on('connect', () => {
      sock.destroy();
      resolve({ ok: true, detail: `${host}:${port} reachable` });
    });
    sock.on('error', (e) => {
      sock.destroy();
      resolve({ ok: false, detail: e.message });
    });
    sock.on('timeout', () => {
      sock.destroy();
      resolve({ ok: false, detail: 'timeout' });
    });
    sock.connect(port, host);
  });
}

function httpProbe(url, timeout = 3000) {
  return new Promise((resolve) => {
    if (!url) return resolve({ ok: false, detail: 'not configured' });
    try {
      const req = http.get(url, { timeout }, (res) => {
        resolve({ ok: res.statusCode < 500, detail: `HTTP ${res.statusCode}` });
        res.resume();
      });
      req.on('error', (e) => resolve({ ok: false, detail: e.message }));
      req.on('timeout', () => {
        req.destroy();
        resolve({ ok: false, detail: 'timeout' });
      });
    } catch (e) {
      resolve({ ok: false, detail: e.message });
    }
  });
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/favicon.ico') {
    res.writeHead(204);
    res.end();
    return;
  }

  const results = await Promise.all(
    CHECKS.map(async (c) => ({ name: c.name, ...(await c.fn()) }))
  );
  const allOk = results.every((r) => r.ok);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Crosspose Hello World &mdash; ${OS}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5;
           display: flex; justify-content: center; padding: 40px 20px; }
    .card { background: #fff; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,.08);
            max-width: 520px; width: 100%; padding: 32px; }
    h1 { font-size: 20px; margin-bottom: 4px; }
    .os { color: #888; font-size: 14px; margin-bottom: 20px; }
    .status { font-size: 16px; font-weight: 600; padding: 12px 16px; border-radius: 8px;
              margin-bottom: 20px; }
    .status.ok { background: #e8f5e9; color: #2e7d32; }
    .status.fail { background: #ffebee; color: #c62828; }
    ul { list-style: none; }
    li { padding: 10px 0; border-bottom: 1px solid #f0f0f0; display: flex;
         align-items: center; gap: 10px; font-size: 15px; }
    li:last-child { border-bottom: none; }
    .icon { font-size: 20px; flex-shrink: 0; }
    .name { font-weight: 500; }
    .detail { color: #888; font-size: 13px; margin-left: auto; }
    .ts { color: #bbb; font-size: 11px; text-align: center; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Crosspose Hello World</h1>
    <div class="os">${OS} container</div>
    <div class="status ${allOk ? 'ok' : 'fail'}">${allOk ? 'All checks passing' : 'One or more checks failing'}</div>
    <ul>
      ${results
        .map(
          (r) =>
            `<li>
          <span class="icon">${r.ok ? '&#9989;' : '&#10060;'}</span>
          <span class="name">${r.name}</span>
          <span class="detail">${r.detail}</span>
        </li>`
        )
        .join('\n      ')}
    </ul>
    <div class="ts">${new Date().toISOString()}</div>
  </div>
</body>
</html>`;

  res.writeHead(allOk ? 200 : 503, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[${OS}] Listening on :${PORT}`);
  console.log(`  SQL_HOST=${process.env.SQL_HOST || '(not set)'}`);
  console.log(`  SB_HOST=${process.env.SB_HOST || '(not set)'}`);
  console.log(`  STORAGE_URL=${process.env.STORAGE_URL || '(not set)'}`);
  console.log(`  PEER_URL=${process.env.PEER_URL || '(not set)'}`);
});
