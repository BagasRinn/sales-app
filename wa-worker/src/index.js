/**
 * Worker absensi WhatsApp (Baileys) â†’ FastAPI.
 *
 * Login pertama kali dengan scan QR. QR juga bisa diambil admin web lewat
 * control server kecil (lihat src/control.js); sesi disimpan di `AUTH_DIR`
 * supaya restart tidak perlu scan ulang.
 */
import 'dotenv/config';

import { rm } from 'node:fs/promises';

import makeWASocket, {
  DisconnectReason,
  fetchLatestBaileysVersion,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import pino from 'pino';
import qrcode from 'qrcode-terminal';

import { sendAttendance } from './backend.js';
import { loadConfig } from './config.js';
import { createControlServer } from './control.js';
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
let relinking = false;
let stopping = false;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Status sesi yang dibaca control server (dipakai admin web). */
const session = {
  status: 'starting', // starting | waiting_qr | connected | disconnected | logged_out | logging_out
  connected: false,
  qr: null,
  phone: null,
  name: null,
  updated_at: new Date().toISOString(),
};

function updateSession(patch) {
  Object.assign(session, patch, { updated_at: new Date().toISOString() });
}

function jidToPhone(jid) {
  const bare = String(jid || '')
    .split('@')[0]
    .split(':')[0];
  return /^\d+$/.test(bare) ? bare : null;
}

async function connect() {
  const { state, saveCreds } = await useMultiFileAuthState(config.authDir);

  let version;
  try {
    ({ version } = await fetchLatestBaileysVersion());
  } catch (error) {
    logger.warn(`[WA] Gagal cek versi WhatsApp Web, pakai default: ${error.message}`);
  }

  const current = makeWASocket({
    ...(version ? { version } : {}),
    auth: state,
    logger,
    browser: ['Sales Attendance', 'Chrome', '1.0.0'],
    markOnlineOnConnect: false,
    syncFullHistory: false,
  });
  sock = current;

  // Event dari socket lama (mis. setelah "Scan ulang") diabaikan supaya tidak
  // menimpa status socket yang baru.
  const isCurrent = () => sock === current;

  current.ev.on('creds.update', saveCreds);

  current.ev.on('connection.update', (update) => {
    if (!isCurrent()) return;
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      updateSession({
        status: 'waiting_qr',
        connected: false,
        qr,
        phone: null,
        name: null,
      });
      logger.info('[WA] QR baru tersedia. Scan lewat admin web atau terminal:');
      qrcode.generate(qr, { small: true });
    }

    if (connection === 'open') {
      updateSession({
        status: 'connected',
        connected: true,
        qr: null,
        phone: jidToPhone(current.user?.id),
        name: current.user?.name || current.user?.verifiedName || null,
      });
      logger.info(
        `[WA] Terhubung ke WhatsApp${session.phone ? ` sebagai ${session.phone}` : ''}.`,
      );
    }

    if (connection === 'close') {
      if (relinking) return; // logout/relink sedang berjalan
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      if (stopping) return;

      if (statusCode === DisconnectReason.loggedOut) {
        updateSession({
          status: 'logged_out',
          connected: false,
          qr: null,
          phone: null,
          name: null,
        });
        logger.error(
          '[WA] Sesi keluar (loggedOut). Buka admin web â†’ Perangkat WhatsApp â†’ ' +
            '"Putuskan & scan ulang" untuk menautkan nomor lagi.',
        );
        return;
      }

      updateSession({ status: 'disconnected', connected: false, qr: null });
      logger.warn(`[WA] Koneksi terputus (code=${statusCode ?? 'unknown'}), reconnect 5 detik...`);
      scheduleReconnect();
    }
  });

  current.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify' || !isCurrent()) return;

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

/**
 * Putuskan sesi saat ini lalu mulai ulang dengan QR baru.
 * Dipakai tombol "Putuskan & scan ulang" di admin web.
 */
async function relink() {
  if (relinking || stopping) return;
  relinking = true;
  updateSession({
    status: 'logging_out',
    connected: false,
    qr: null,
    phone: null,
    name: null,
  });

  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  const previous = sock;
  sock = null;
  try {
    await Promise.race([
      Promise.resolve(previous?.logout('scan ulang dari admin web')),
      sleep(3000),
    ]);
  } catch (error) {
    logger.warn(`[WA] Logout sesi lama gagal (lanjut hapus sesi): ${error.message}`);
  }
  try {
    previous?.end(undefined);
  } catch {
    // abaikan
  }

  // Beri waktu Baileys menyelesaikan penulisan creds sebelum folder dihapus,
  // supaya connect berikutnya benar-benar mulai dari nol dan memunculkan QR.
  await sleep(300);
  try {
    await rm(config.authDir, { recursive: true, force: true });
  } catch (error) {
    logger.error(`[WA] Gagal menghapus sesi lama: ${error.message}`);
  }

  relinking = false;
  updateSession({ status: 'starting' });
  logger.info('[WA] Sesi lama dihapus, menyiapkan QR baru...');
  await connect();
}

function scheduleReconnect() {
  if (stopping || relinking || reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect().catch((error) => {
      logger.error(`[WA] Reconnect gagal: ${error.message}`);
      updateSession({ status: 'disconnected', connected: false, qr: null });
      scheduleReconnect();
    });
  }, 5000);
}

const controlServer = createControlServer({
  apiKey: config.internalApiKey,
  getState: () => ({ ...session }),
  onLogout: relink,
  logger,
});
controlServer.on('error', (error) => {
  logger.error(`[WA] Control server error: ${error.message}`);
});
controlServer.listen(config.controlPort, config.controlHost, () => {
  logger.info(
    `[WA] Control server aktif di http://${config.controlHost}:${config.controlPort}`,
  );
});

function shutdown(signal) {
  stopping = true;
  if (reconnectTimer) clearTimeout(reconnectTimer);
  logger.info(`[WA] Menerima ${signal}, menutup koneksi...`);
  try {
    controlServer.close();
  } catch {
    // abaikan
  }
  try {
    sock?.end(undefined);
  } catch {
    // abaikan â€” proses tetap keluar
  }
  setTimeout(() => process.exit(0), 500);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

connect().catch((error) => {
  logger.error(`[WA] Gagal start: ${error.stack || error.message}`);
  updateSession({ status: 'disconnected', connected: false, qr: null });
  scheduleReconnect();
});
