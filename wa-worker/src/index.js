/**
 * Worker absensi WhatsApp (Baileys) → FastAPI.
 *
 * Login pertama kali dengan scan QR di terminal; sesi disimpan di
 * `AUTH_DIR` (default `./auth_info_baileys`) supaya tidak perlu scan ulang.
 */
import 'dotenv/config';

import makeWASocket, {
  DisconnectReason,
  fetchLatestBaileysVersion,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import pino from 'pino';
import qrcode from 'qrcode-terminal';

import { sendAttendance } from './backend.js';
import { loadConfig } from './config.js';
import { buildAttendancePayload } from './parser.js';

let config;
try {
  config = loadConfig();
} catch (error) {
  console.error(`[WA] ${error.message}`);
  process.exit(1);
}

const logger = pino({ level: config.logLevel });
let sock = null;
let reconnectTimer = null;
let stopping = false;

async function connect() {
  const { state, saveCreds } = await useMultiFileAuthState(config.authDir);

  let version;
  try {
    ({ version } = await fetchLatestBaileysVersion());
  } catch (error) {
    logger.warn(`[WA] Gagal cek versi WhatsApp Web, pakai default: ${error.message}`);
  }

  sock = makeWASocket({
    ...(version ? { version } : {}),
    auth: state,
    logger,
    browser: ['Sales Attendance', 'Chrome', '1.0.0'],
    markOnlineOnConnect: false,
    syncFullHistory: false,
  });

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      logger.info('[WA] Scan QR berikut dengan WhatsApp > Perangkat Tertaut:');
      qrcode.generate(qr, { small: true });
    }

    if (connection === 'open') {
      logger.info('[WA] Terhubung ke WhatsApp.');
    }

    if (connection === 'close') {
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      if (statusCode === DisconnectReason.loggedOut) {
        logger.error(
          '[WA] Sesi keluar (loggedOut). Hapus folder auth lalu jalankan ulang untuk scan QR.',
        );
        process.exit(1);
      }
      if (stopping) return;

      logger.warn(`[WA] Koneksi terputus (code=${statusCode ?? 'unknown'}), reconnect 5 detik...`);
      scheduleReconnect();
    }
  });

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;

    for (const msg of messages) {
      const payload = buildAttendancePayload(msg, {
        allowedGroups: config.allowedGroups,
      });
      if (!payload) continue;

      // Dikirim berurutan agar tidak membanjiri backend saat grup ramai.
      await sendAttendance({ config, payload, logger });
    }
  });
}

function scheduleReconnect() {
  if (stopping || reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect().catch((error) => {
      logger.error(`[WA] Reconnect gagal: ${error.message}`);
      scheduleReconnect();
    });
  }, 5000);
}

function shutdown(signal) {
  stopping = true;
  if (reconnectTimer) clearTimeout(reconnectTimer);
  logger.info(`[WA] Menerima ${signal}, menutup koneksi...`);
  try {
    sock?.end(undefined);
  } catch {
    // abaikan — proses tetap keluar
  }
  setTimeout(() => process.exit(0), 500);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

connect().catch((error) => {
  logger.error(`[WA] Gagal start: ${error.stack || error.message}`);
  scheduleReconnect();
});
