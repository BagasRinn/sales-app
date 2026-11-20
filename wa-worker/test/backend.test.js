import assert from 'node:assert/strict';
import test from 'node:test';

import { sendAttendance } from '../src/backend.js';
import { loadConfig } from '../src/config.js';

const silentLogger = { info() {}, warn() {}, error() {} };

function baseConfig(overrides = {}) {
  return {
    fastapiUrl: 'http://api.test',
    internalApiKey: 'secret-key',
    maxRetries: 3,
    retryBaseDelayMs: 1,
    requestTimeoutMs: 1000,
    ...overrides,
  };
}

const payload = {
  sender_phone: '6281234567890',
  outlet_code: 'OUT-01',
  outlet_name: 'Toko A',
  outlet_channel: 'GT',
  wa_message_id: 'MSG-1',
};

test('loadConfig fail-fast bila env wajib kosong', () => {
  assert.throws(() => loadConfig({}), /FASTAPI_URL, INTERNAL_API_KEY/);
});

test('loadConfig memangkas URL dan memecah ALLOWED_GROUP_JIDS', () => {
  const config = loadConfig({
    FASTAPI_URL: ' http://api.test/ ',
    INTERNAL_API_KEY: ' k ',
    ALLOWED_GROUP_JIDS: 'a@g.us, b@g.us ,',
  });
  assert.equal(config.fastapiUrl, 'http://api.test');
  assert.equal(config.internalApiKey, 'k');
  assert.deepEqual(config.allowedGroups, ['a@g.us', 'b@g.us']);
  assert.equal(config.maxRetries, 3);
});

test('sendAttendance sukses pada percobaan pertama', async () => {
  let calls = 0;
  const result = await sendAttendance({
    config: baseConfig(),
    payload,
    logger: silentLogger,
    fetchImpl: async (url, options) => {
      calls += 1;
      assert.equal(url, 'http://api.test/api/v1/webhooks/wa-attendance');
      assert.equal(options.headers['X-Internal-API-Key'], 'secret-key');
      assert.deepEqual(JSON.parse(options.body), payload);
      return new Response('{"status":"created"}', { status: 201 });
    },
  });

  assert.equal(calls, 1);
  assert.equal(result.ok, true);
  assert.equal(result.status, 201);
});

test('sendAttendance retry pada 5xx lalu sukses', async () => {
  let calls = 0;
  const delays = [];
  const result = await sendAttendance({
    config: baseConfig(),
    payload,
    logger: silentLogger,
    sleepImpl: async (ms) => delays.push(ms),
    fetchImpl: async () => {
      calls += 1;
      return calls === 1
        ? new Response('boom', { status: 500 })
        : new Response('{"status":"ignored"}', { status: 200 });
    },
  });

  assert.equal(calls, 2);
  assert.equal(result.ok, true);
  assert.deepEqual(delays, [1]);
});

test('sendAttendance tidak retry pada 4xx', async () => {
  let calls = 0;
  const result = await sendAttendance({
    config: baseConfig(),
    payload,
    logger: silentLogger,
    sleepImpl: async () => {},
    fetchImpl: async () => {
      calls += 1;
      return new Response('unauthorized', { status: 401 });
    },
  });

  assert.equal(calls, 1);
  assert.equal(result.ok, false);
  assert.equal(result.status, 401);
  assert.match(result.error, /401/);
});

test('sendAttendance menyerah setelah semua percobaan gagal', async () => {
  let calls = 0;
  const result = await sendAttendance({
    config: baseConfig({ maxRetries: 2 }),
    payload,
    logger: silentLogger,
    sleepImpl: async () => {},
    fetchImpl: async () => {
      calls += 1;
      throw new Error('network down');
    },
  });

  assert.equal(calls, 2);
  assert.equal(result.ok, false);
  assert.match(result.error, /network down/);
});
