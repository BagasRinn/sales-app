// Menempelkan build id ke entrypoint Flutter web supaya browser selalu
// mengambil versi terbaru tanpa user perlu menghapus cache.
//
// Flutter web memakai nama file tetap (main.dart.js, flutter_bootstrap.js),
// sehingga cache 1 tahun pun jadi masalah: isi berubah, URL tidak. Script ini
// menambahkan ?v=<buildId> ke URL tersebut. Karena index.html selalu di-serve
// dengan Cache-Control: no-cache, URL yang dipakai selalu URL build terbaru.
//
// Pemakaian:
//   node scripts/stamp_flutter_web.mjs sales-app/sales_web/build/web
//   BUILD_ID=run42-abc1234 node scripts/stamp_flutter_web.mjs <dir build/web>
//
// Script ini sengaja GAGAL KERAS kalau pola Flutter tidak ditemukan, supaya
// deploy tidak diam-diam kembali ke perilaku lama (cache 1 tahun tanpa versi).

import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = fileURLToPath(new URL('..', import.meta.url));

const target = process.argv[2];
if (!target) {
  console.error('[stamp] argumen wajib: path ke folder build/web');
  process.exit(1);
}

const root = resolve(repoRoot, target);

try {
  if (!statSync(root).isDirectory()) throw new Error('bukan folder');
} catch {
  console.error(`[stamp] folder tidak ditemukan: ${root}`);
  process.exit(1);
}

const buildId = (process.env.BUILD_ID || String(Date.now()))
  .replace(/[^a-zA-Z0-9._-]/g, '')
  .slice(0, 24);

if (!buildId) {
  console.error('[stamp] BUILD_ID kosong setelah sanitasi');
  process.exit(1);
}

function patch(file, pattern, replacement, { optional = false } = {}) {
  const path = join(root, file);
  let before;
  try {
    before = readFileSync(path, 'utf8');
  } catch {
    console.error(`[stamp] file tidak ditemukan: ${path}`);
    process.exit(1);
  }

  // Cek keberadaan pola terpisah dari "apakah isi berubah", supaya script aman
  // dijalankan dua kali dengan build id yang sama.
  if (!new RegExp(pattern).test(before)) {
    if (optional) {
      console.log(`[stamp]   ${file}: pola opsional tidak ada, dilewati`);
      return;
    }
    console.error(
      `[stamp] pola tidak ketemu di ${file}. Format output Flutter berubah?\n` +
        `        Pola: ${pattern}`,
    );
    process.exit(1);
  }

  writeFileSync(path, before.replace(pattern, replacement));
  console.log(`[stamp]   ${file} -> ?v=${buildId}`);
}

/**
 * Menghapus komentar `//# sourceMappingURL=...` yang menunjuk file map yang
 * tidak ikut di-deploy (mis. flutter.js.map). Kalau dibiarkan, request map-nya
 * dijawab index.html oleh rewrite SPA dan gagal di-parse.
 */
function stripSourceMapReference(file) {
  const path = join(root, file);
  let before;
  try {
    before = readFileSync(path, 'utf8');
  } catch {
    console.error(`[stamp] file tidak ditemukan: ${path}`);
    process.exit(1);
  }

  // Komentar ini bisa berada di tengah file: flutter_bootstrap.js adalah isi
  // flutter.js yang disambung dengan blok konfigurasi build.
  const after = before.replace(/^\/\/# sourceMappingURL=\S+[ \t\r]*\n?/gm, '');
  if (after === before) {
    console.log(`[stamp]   ${file}: tidak ada sourceMappingURL, dilewati`);
    return;
  }

  writeFileSync(path, after);
  console.log(`[stamp]   ${file}: sourceMappingURL dilepas`);
}

console.log(`[stamp] build id: ${buildId}`);

patch(
  'index.html',
  /src="flutter_bootstrap\.js(\?[^"]*)?"/,
  `src="flutter_bootstrap.js?v=${buildId}"`,
);

// Opsional: hanya app yang memasang <link rel="preload"> untuk main.dart.js.
// Kalau tidak ada, deploy tetap jalan (dipakai bersama sales_web).
patch(
  'index.html',
  /<link rel="preload" href="main\.dart\.js(\?[^"]*)?" as="script">/,
  `<link rel="preload" href="main.dart.js?v=${buildId}" as="script">`,
  { optional: true },
);

patch(
  'flutter_bootstrap.js',
  /"mainJsPath":"main\.dart\.js(\?[^"]*)?"/,
  `"mainJsPath":"main.dart.js?v=${buildId}"`,
);

// flutter_bootstrap.js adalah salinan flutter.js + config, dan masih membawa
// komentar `//# sourceMappingURL=flutter.js.map` padahal file map itu tidak
// ikut di-deploy. Tanpa ini browser/DevTools meminta /flutter.js.map, Firebase
// me-rewrite ke index.html, lalu map gagal di-parse
// ("SyntaxError: Unexpected token '<'") dan muncul di laporan Lighthouse.
stripSourceMapReference('flutter_bootstrap.js');

writeFileSync(
  join(root, 'build-id.json'),
  JSON.stringify({ buildId, builtAt: new Date().toISOString() }),
);
console.log('[stamp]   build-id.json ditulis');

console.log('[stamp] selesai');
