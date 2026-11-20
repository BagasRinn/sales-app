/** Konfigurasi worker dari environment (fail-fast bila wajib belum diisi). */

const DEFAULTS = {
  authDir: './auth_info_baileys',
  logLevel: 'info',
  maxRetries: 3,
  retryBaseDelayMs: 1000,
  requestTimeoutMs: 10000,
};

/**
 * @param {NodeJS.ProcessEnv} env
 */
export function loadConfig(env = process.env) {
  const fastapiUrl = (env.FASTAPI_URL || '').trim().replace(/\/+$/, '');
  const internalApiKey = (env.INTERNAL_API_KEY || '').trim();

  const missing = [];
  if (!fastapiUrl) missing.push('FASTAPI_URL');
  if (!internalApiKey) missing.push('INTERNAL_API_KEY');
  if (missing.length > 0) {
    throw new Error(
      `Environment wajib belum diisi: ${missing.join(', ')}. ` +
        'Lihat .env.example untuk contoh lengkap.',
    );
  }

  return {
    fastapiUrl,
    internalApiKey,
    allowedGroups: (env.ALLOWED_GROUP_JIDS || '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
    authDir: (env.AUTH_DIR || DEFAULTS.authDir).trim(),
    logLevel: (env.LOG_LEVEL || DEFAULTS.logLevel).trim(),
    maxRetries: toPositiveInt(env.MAX_RETRIES, DEFAULTS.maxRetries),
    retryBaseDelayMs: toPositiveInt(
      env.RETRY_BASE_DELAY_MS,
      DEFAULTS.retryBaseDelayMs,
    ),
    requestTimeoutMs: toPositiveInt(
      env.REQUEST_TIMEOUT_MS,
      DEFAULTS.requestTimeoutMs,
    ),
  };
}

function toPositiveInt(raw, fallback) {
  const value = Number.parseInt(String(raw ?? ''), 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}
