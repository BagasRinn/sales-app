import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildAttendancePayload,
  cleanSenderJid,
  extractMessageContent,
  messageTimestampToWitaIso,
  normalizePhoneNumber,
  parseAttendanceMessage,
} from '../src/parser.js';

test('parseAttendanceMessage menerima format 3 segmen', () => {
  assert.deepEqual(parseAttendanceMessage('OUT-042#Toko Berkah Jaya#GT'), {
    outletCode: 'OUT-042',
    outletName: 'Toko Berkah Jaya',
    outletChannel: 'GT',
  });
});

test('parseAttendanceMessage memangkas spasi di sekitar #', () => {
  assert.deepEqual(parseAttendanceMessage('  OUT-01 #  Toko A  #  Semi Grosir '), {
    outletCode: 'OUT-01',
    outletName: 'Toko A',
    outletChannel: 'Semi Grosir',
  });
});

for (const invalid of [
  'OUT-01#Toko A',
  'OUT-01#Toko A#GT#EXTRA',
  'OUT-01##GT',
  '#Toko A#GT',
  'obrolan biasa',
  '',
  null,
  undefined,
]) {
  test(`parseAttendanceMessage menolak ${JSON.stringify(invalid)}`, () => {
    assert.equal(parseAttendanceMessage(invalid), null);
  });
}

test('extractMessageContent mengambil conversation', () => {
  assert.deepEqual(extractMessageContent({ conversation: 'A#B#C' }), {
    text: 'A#B#C',
    hasImage: false,
  });
});

test('extractMessageContent mengambil extendedTextMessage', () => {
  assert.deepEqual(
    extractMessageContent({ extendedTextMessage: { text: 'A#B#C' } }),
    { text: 'A#B#C', hasImage: false },
  );
});

test('extractMessageContent mengambil caption gambar sebagai bukti foto', () => {
  assert.deepEqual(
    extractMessageContent({ imageMessage: { caption: 'A#B#C' } }),
    { text: 'A#B#C', hasImage: true },
  );
});

test('extractMessageContent menelusuri pesan ephemeral', () => {
  assert.deepEqual(
    extractMessageContent({
      ephemeralMessage: { message: { imageMessage: { caption: 'A#B#C' } } },
    }),
    { text: 'A#B#C', hasImage: true },
  );
});

test('cleanSenderJid membuang suffix server dan device', () => {
  assert.equal(cleanSenderJid('6281234567890:12@s.whatsapp.net'), '6281234567890');
  assert.equal(cleanSenderJid('123456789012345@lid'), '123456789012345');
  assert.equal(cleanSenderJid(''), '');
});

test('normalizePhoneNumber menyamakan format 62', () => {
  assert.equal(normalizePhoneNumber('0812-3456-7890'), '6281234567890');
  assert.equal(normalizePhoneNumber('+62 812 3456 7890'), '6281234567890');
  assert.equal(normalizePhoneNumber('62081234567890'), '6281234567890');
  assert.equal(normalizePhoneNumber('81234567890'), '6281234567890');
  assert.equal(normalizePhoneNumber('123456789012345'), '123456789012345');
});

test('messageTimestampToWitaIso memakai offset +08:00', () => {
  assert.equal(
    messageTimestampToWitaIso(1_700_000_000),
    '2023-11-15T06:13:20.000+08:00',
  );
});

test('messageTimestampToWitaIso menerima milidetik', () => {
  assert.equal(
    messageTimestampToWitaIso(1_700_000_000_000),
    '2023-11-15T06:13:20.000+08:00',
  );
});

function groupMessage(overrides = {}) {
  return {
    key: {
      remoteJid: '120363000000000000@g.us',
      participant: '6281234567890@s.whatsapp.net',
      id: 'MSG-1',
      fromMe: false,
    },
    pushName: 'Budi',
    messageTimestamp: 1_700_000_000,
    message: { conversation: 'OUT-01#Toko A#GT' },
    ...overrides,
  };
}

test('buildAttendancePayload membentuk payload lengkap', () => {
  const payload = buildAttendancePayload(groupMessage());
  assert.deepEqual(payload, {
    sender_phone: '6281234567890',
    sender_push_name: 'Budi',
    outlet_code: 'OUT-01',
    outlet_name: 'Toko A',
    outlet_channel: 'GT',
    has_photo_proof: false,
    wa_group_id: '120363000000000000@g.us',
    wa_message_id: 'MSG-1',
    message_timestamp: '2023-11-15T06:13:20.000+08:00',
    raw_message: 'OUT-01#Toko A#GT',
  });
});

test('buildAttendancePayload memakai participantAlt untuk @lid', () => {
  const payload = buildAttendancePayload(
    groupMessage({
      key: {
        remoteJid: '120363000000000000@g.us',
        participantAlt: '123456789012345@lid',
        participant: '6281234567890@s.whatsapp.net',
        id: 'MSG-2',
        fromMe: false,
      },
      pushName: undefined,
    }),
  );
  assert.equal(payload.sender_phone, '123456789012345');
  assert.equal(payload.sender_push_name, 'Unknown');
});

test('buildAttendancePayload mengabaikan pesan sendiri dan non-grup', () => {
  assert.equal(buildAttendancePayload(groupMessage({ key: { fromMe: true } })), null);
  assert.equal(
    buildAttendancePayload(
      groupMessage({
        key: { remoteJid: '6281234567890@s.whatsapp.net', id: 'x', fromMe: false },
      }),
    ),
    null,
  );
});

test('buildAttendancePayload menghormati ALLOWED_GROUP_JIDS', () => {
  assert.equal(
    buildAttendancePayload(groupMessage(), { allowedGroups: ['999@g.us'] }),
    null,
  );
  assert.ok(
    buildAttendancePayload(groupMessage(), {
      allowedGroups: ['120363000000000000@g.us'],
    }),
  );
});

test('buildAttendancePayload mengabaikan pesan yang bukan format absensi', () => {
  assert.equal(
    buildAttendancePayload(
      groupMessage({ message: { conversation: 'Halo semua' } }),
    ),
    null,
  );
});
