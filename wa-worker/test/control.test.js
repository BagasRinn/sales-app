import assert from 'node:assert/strict';
import test from 'node:test';

import { createControlServer } from '../src/control.js';

const KEY = 'test-internal-key';
const silentLogger = { info() {}, warn() {}, error() {} };

async function withServer(options, fn) {
  const server = createControlServer({
    apiKey: KEY,
    getState: () => ({}),
    onLogout: () => {},
    logger: silentLogger,
    ...options,
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('status requires the internal API key', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(`${base}/status`);
    assert.equal(response.status, 401);
  });
});

test('status rejects a wrong internal API key', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(`${base}/status`, {
      headers: { 'X-Internal-API-Key': 'wrong' },
    });
    assert.equal(response.status, 401);
  });
});

test('server is fail-closed when internal key is empty', async () => {
  await withServer({ apiKey: '' }, async (base) => {
    const response = await fetch(`${base}/status`, {
      headers: { 'X-Internal-API-Key': 'anything' },
    });
    assert.equal(response.status, 503);
  });
});

test('status returns the current session snapshot', async () => {
  const state = {
    status: 'waiting_qr',
    connected: false,
    qr: '2@abc,def',
    phone: null,
    name: null,
  };
  await withServer({ getState: () => state }, async (base) => {
    const response = await fetch(`${base}/status`, {
      headers: { 'X-Internal-API-Key': KEY },
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), state);
  });
});

test('logout responds immediately and invokes the relink callback', async () => {
  let resolveLogout;
  const logoutCalled = new Promise((resolve) => {
    resolveLogout = resolve;
  });
  await withServer(
    { onLogout: () => resolveLogout() },
    async (base) => {
      const response = await fetch(`${base}/logout`, {
        method: 'POST',
        headers: { 'X-Internal-API-Key': KEY },
      });
      assert.equal(response.status, 202);
      const body = await response.json();
      assert.equal(body.status, 'logging_out');
      await logoutCalled;
    },
  );
});

test('unknown route returns 404', async () => {
  await withServer({}, async (base) => {
    const response = await fetch(`${base}/nope`, {
      headers: { 'X-Internal-API-Key': KEY },
    });
    assert.equal(response.status, 404);
  });
});
