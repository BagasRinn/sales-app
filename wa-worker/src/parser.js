/**
 * Parser pesan absensi WhatsApp.
 *
 * Format yang diterima hanya: `KODE OUTLET#NAMA OUTLET#CHANNEL OUTLET`
 * (spasi di sekitar `#` diperbolehkan). Semua teks lain diabaikan agar
 * obrolan biasa di grup tidak ikut tercatat sebagai absensi.
 */

const SEGMENT_COUNT = 3;

/**
 * @param {unknown} text
 * @returns {{outletCode: string, outletName: string, outletChannel: string} | null}
 */
export function parseAttendanceMessage(text) {
  if (typeof text !== 'string') return null;

  const parts = text.split('#').map((part) => part.trim());
  if (parts.length !== SEGMENT_COUNT) return null;
  if (parts.some((part) => part.length === 0)) return null;

  return {
    outletCode: parts[0],
    outletName: parts[1],
    outletChannel: parts[2],
  };
}

/**
 * Ambil teks/caption dari berbagai bentuk pesan Baileys.
 * @param {any} message
 * @returns {{text: string | null, hasImage: boolean}}
 */
export function extractMessageContent(message) {
  if (!message || typeof message !== 'object') {
    return { text: null, hasImage: false };
  }

  if (typeof message.conversation === 'string') {
    return { text: message.conversation, hasImage: false };
  }

  if (typeof message.extendedTextMessage?.text === 'string') {
    return { text: message.extendedTextMessage.text, hasImage: false };
  }

  if (message.imageMessage) {
    return {
      text:
        typeof message.imageMessage.caption === 'string'
          ? message.imageMessage.caption
          : null,
      hasImage: true,
    };
  }

  // Pesan bisa dibungkus ephemeral / view-once / dokumen. Telusuri isinya.
  for (const key of [
    'ephemeralMessage',
    'viewOnceMessage',
    'viewOnceMessageV2',
    'viewOnceMessageV2Extension',
    'documentWithCaptionMessage',
  ]) {
    const nested = message[key]?.message;
    if (nested) {
      const result = extractMessageContent(nested);
      if (result.text || result.hasImage) return result;
    }
  }

  return { text: null, hasImage: false };
}

/**
 * JID pengirim: `participantAlt` didahulukan untuk antisipasi format @lid.
 * @param {any} key
 * @returns {string}
 */
export function senderJidFromKey(key) {
  return key?.participantAlt || key?.participant || key?.remoteJid || '';
}

/**
 * Buang suffix server + device (`:12`) dari JID.
 * @param {unknown} jid
 * @returns {string}
 */
export function cleanSenderJid(jid) {
  if (!jid) return '';
  const user = String(jid).split('@')[0];
  return user.split(':')[0];
}

/**
 * Samakan format nomor dengan backend: `628...` (tanpa `+`, spasi, tanda hubung).
 * Nomor non-Indonesia (mis. LID) hanya dibersihkan digitnya.
 * @param {unknown} phone
 * @returns {string}
 */
export function normalizePhoneNumber(phone) {
  if (phone === null || phone === undefined) return '';
  const digits = String(phone).replace(/\D/g, '');
  if (!digits) return '';
  if (digits.startsWith('620')) return `62${digits.slice(3)}`;
  if (digits.startsWith('0')) return `62${digits.slice(1)}`;
  if (digits.startsWith('62')) return digits;
  if (digits.startsWith('8')) return `62${digits}`;
  return digits;
}

/**
 * `msg.messageTimestamp` bisa berupa number, string, atau Long protobuf.
 * @param {unknown} value
 * @returns {string} ISO-8601 dengan offset WITA (+08:00)
 */
export function messageTimestampToWitaIso(value) {
  const numeric = Number(value);
  let ms;
  if (!Number.isFinite(numeric) || numeric <= 0) {
    ms = Date.now();
  } else {
    ms = numeric > 10_000_000_000 ? numeric : numeric * 1000;
  }

  const wita = new Date(ms + 8 * 60 * 60 * 1000);
  return `${wita.toISOString().slice(0, -1)}+08:00`;
}

/**
 * Ubah satu objek `messages.upsert` menjadi payload webhook, atau null bila
 * pesan bukan absensi yang valid.
 * @param {any} msg
 * @param {{allowedGroups?: string[]}} [options]
 */
export function buildAttendancePayload(msg, options = {}) {
  if (!msg || msg.key?.fromMe) return null;

  const remoteJid = msg.key?.remoteJid || '';
  if (!remoteJid.endsWith('@g.us')) return null;

  const allowedGroups = options.allowedGroups || [];
  if (allowedGroups.length > 0 && !allowedGroups.includes(remoteJid)) return null;

  const { text, hasImage } = extractMessageContent(msg.message);
  const parsed = parseAttendanceMessage(text);
  if (!parsed) return null;

  const senderJid = senderJidFromKey(msg.key);
  const senderPhone = normalizePhoneNumber(cleanSenderJid(senderJid));
  if (!senderPhone) return null;

  return {
    sender_phone: senderPhone,
    sender_push_name: (msg.pushName || 'Unknown').trim() || 'Unknown',
    outlet_code: parsed.outletCode,
    outlet_name: parsed.outletName,
    outlet_channel: parsed.outletChannel,
    has_photo_proof: hasImage,
    wa_group_id: remoteJid,
    wa_message_id: msg.key?.id || null,
    message_timestamp: messageTimestampToWitaIso(msg.messageTimestamp),
    raw_message: text,
  };
}
