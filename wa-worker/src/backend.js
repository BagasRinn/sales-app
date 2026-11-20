/** Pengiriman payload absensi ke FastAPI dengan retry sederhana. */

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * @param {object} params
 * @param {object} params.config
 * @param {object} params.payload
 * @param {(...args: any[]) => Promise<any>} [params.fetchImpl]
 * @param {(ms: number) => Promise<void>} [params.sleepImpl]
 * @param {{info: Function, warn: Function, error: Function}} [params.logger]
 * @returns {Promise<{ok: boolean, status?: number, body?: string, error?: string}>}
 */
export async function sendAttendance({
  config,
  payload,
  fetchImpl = globalThis.fetch,
  sleepImpl = sleep,
  logger = console,
}) {
  const url = `${config.fastapiUrl}/api/v1/webhooks/wa-attendance`;
  const attempts = config.maxRetries ?? 3;
  let lastError = 'unknown error';

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetchImpl(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Internal-API-Key': config.internalApiKey,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(config.requestTimeoutMs ?? 10000),
      });
      const body = await response.text().catch(() => '');

      if (response.ok) {
        logger.info(
          `[WA] Terkirim (${response.status}) outlet=${payload.outlet_code} ` +
            `msg=${payload.wa_message_id ?? '-'}`,
        );
        return { ok: true, status: response.status, body };
      }

      lastError = `HTTP ${response.status}: ${body.slice(0, 200)}`;

      // 4xx berarti payload/kunci salah; retry tidak akan menolong.
      if (response.status >= 400 && response.status < 500) {
        logger.error(`[WA] Ditolak backend (${response.status}): ${body.slice(0, 200)}`);
        return { ok: false, status: response.status, body, error: lastError };
      }

      logger.warn(`[WA] Backend error (${response.status}), percobaan ${attempt}/${attempts}`);
    } catch (error) {
      lastError = error?.message || String(error);
      logger.warn(`[WA] Gagal kirim (${lastError}), percobaan ${attempt}/${attempts}`);
    }

    if (attempt < attempts) {
      const delay = (config.retryBaseDelayMs ?? 1000) * 2 ** (attempt - 1);
      await sleepImpl(delay);
    }
  }

  logger.error(`[WA] Menyerah setelah ${attempts} percobaan: ${lastError}`);
  return { ok: false, error: lastError };
}
