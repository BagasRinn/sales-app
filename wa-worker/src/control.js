/**
 * HTTP control server kecil untuk pairing WhatsApp lewat admin web.
 *
 * Hanya mendengarkan di network internal (Docker) atau localhost. Semua
 * request wajib membawa `X-Internal-API-Key` yang sama dengan backend FastAPI.
 * Kalau key kosong, server menolak semua request (fail-closed) — QR tidak
 * boleh bisa diambil tanpa autentikasi.
 */
import { createHash, timingSafeEqual } from 'node:crypto';
import http from 'node:http';

function safeEqual(left, right) {
  const a = createHash('sha256').update(String(left)).digest();
  const b = createHash('sha256').update(String(right)).digest();
  return timingSafeEqual(a, b);
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

/**
 * @param {object} params
 * @param {string} params.apiKey Shared secret; kosong = tolak semua.
 * @param {() => object} params.getState Snapshot status sesi terkini.
 * @param {() => Promise<void> | void} params.onLogout Putuskan sesi lalu
 *   siapkan QR baru.
 * @param {{info: Function, warn: Function, error: Function}} [params.logger]
 * @returns {http.Server}
 */
export function createControlServer({
  apiKey,
  getState,
  onLogout,
  logger = console,
}) {
  const expectedKey = String(apiKey ?? '').trim();

  return http.createServer((req, res) => {
    if (!expectedKey) {
      sendJson(res, 503, {
        error: 'CONTROL_SERVER_DISABLED',
        message: 'INTERNAL_API_KEY kosong; control server nonaktif.',
      });
      return;
    }

    const supplied = req.headers['x-internal-api-key'];
    if (!supplied || !safeEqual(supplied, expectedKey)) {
      sendJson(res, 401, {
        error: 'UNAUTHORIZED',
        message: 'X-Internal-API-Key tidak valid.',
      });
      return;
    }

    let pathname;
    try {
      pathname = new URL(req.url || '/', 'http://localhost').pathname;
    } catch {
      pathname = '/';
    }

    if (req.method === 'GET' && pathname === '/status') {
      try {
        sendJson(res, 200, getState());
      } catch (error) {
        logger.error(`[WA] Gagal membaca status sesi: ${error.message}`);
        sendJson(res, 500, {
          error: 'STATE_ERROR',
          message: 'Gagal membaca status sesi.',
        });
      }
      return;
    }

    if (req.method === 'POST' && pathname === '/logout') {
      sendJson(res, 202, {
        status: 'logging_out',
        message: 'Sesi diputuskan; QR baru akan segera tersedia.',
      });
      // Jalankan setelah response terkirim supaya request tidak menggantung
      // selama proses logout + reconnect.
      setImmediate(() => {
        Promise.resolve()
          .then(onLogout)
          .catch((error) =>
            logger.error(`[WA] Gagal logout/relink: ${error.message}`),
          );
      });
      return;
    }

    sendJson(res, 404, {
      error: 'NOT_FOUND',
      message: 'Endpoint tidak ditemukan.',
    });
  });
}
