# Redesign Keranjang Produk — Plan (DRAFT)

> **Status:** DRAFT — disimpan untuk later, belum final
> **Disimpan:** 2026-10-06
> **Revisit:** Setelah fitur-fitur lain selesai direvisi

---

## Context

Halaman Review Order (`step_review.dart`) terasa sempit dan membingungkan di mobile. User sulit scan isi keranjang karena:
- Informasi terlalu padat dalam 1 baris (nama + harga + stepper + diskon + menu)
- Diskon diedit in-place (expandable panel) yang makan ruang
- Hapus tersembunyi di menu 3-titik
- Tidak ada running total yang terlihat saat scroll

---

## Keputusan Desain (sudah disetujui user)

1. **Desain keseluruhan** sama dengan sekarang — tidak ada perubahan struktur halaman
2. **Hanya layout dalam card produk** yang di-adjust: 2-baris, stepper lebih besar
3. **Diskon** → bottom sheet (bukan inline expand)
4. **Barang Gratis** → bottom sheet (mirip struktur diskon)
5. **Back button** ← → langsung ke step Produk (tanpa dialog)
6. **Batal Order** → tombol terpisah dengan dialog konfirmasi
7. **Ganti Toko** → tombol di bawah info toko
8. **Progress bar** → di atas info toko, biru=lalu&aktif, abu=belum, shadow ring untuk aktif
9. **Tombol +** → filled biru (#2563EB)
10. **Tombol ×** → filled merah (#DC2626)
11. **Ganti Tipe Order** → dialog konfirmasi kalau tipe beda (REGULER→4P): "Produk reguler di keranjang akan dihapus"
12. **Tanpa placeholder gambar/icon**

---

## File yang Dimodifikasi

- `sales-app/lib/presentation/screens/order_flow/step_review.dart` — utama
- `sales-app/lib/presentation/screens/order_flow/step_pick_products.dart` — qty stepper unification
- `sales-app/lib/presentation/screens/order_flow/order_flow_screen.dart` — back behavior + batal order button + ganti tipe order

---

## Komponen Baru

### 1. `_CartLineItem` — card produk baru
- **Layout 2-baris:**
  - Baris 1: nama produk (max 2 lines, ellipsis) + harga subtotal
  - Baris 2: "× qty · harga/unit" + stepper
- Border-radius 12, padding 14
- GRATIS badge (hijau) di samping Nama
- Diskon summary inline di bawah nama (hijau, misal: "−10% · −Rp5.000")
- Action bar di bawah: [Diskon] [Gratis] [× hapus] — × filled merah
- Hapus = tap tombol × (tanpa swipe)
- Tombol + filled biru, − outline

### 2. `_DiscountBottomSheet` — bottom sheet diskon
- Header: "Edit Diskon" + nama produk + tombol × tutup
- 3 layer diskon, tiap layer:
  - Toggle chip: [%] [Rp]
  - Text input angka
  - Preview potongan: "−Rp18.000" (hijau)
  - Tombol "Hapus" per layer
- "Tambah Diskon 3" button (dashed, muncul hanya jika layer 1 & 2 aktif)
- Divider + subtotal after discount
- Tombol "Simpan" (primary, full-width, biru)

### 3. `_GratisBottomSheet` — bottom sheet barang gratis
- Bottom sheet (mirip struktur diskon sheet)
- Header: "Promo Barang Gratis" + info
- Info produk yang di-gratis-kan
- Stepper jumlah gratis
- Info box: "Item gratis = diskon 100% (Rp0)"
- Tombol [Batal] [Tambah Gratis] (hijau)

### 4. `_BatalOrderConfirmDialog` — dialog konfirmasi
- Small centered dialog
- "Batal Order?"
- "Perubahan yang belum disimpan akan hilang."
- [Tetap di Sini] [Batal] (merah)

### 5. `_RunningTotalChip` — sticky total di section header
- Badge di bawah judul "Produk (N)": "N item · Rp X"
- Tetap terlihat saat scroll
- Warna: background hijau muda, text hijau

### 6. `_SharedQtyStepper` — unifikasi stepper
- Satu widget untuk step_pick_products.dart dan step_review.dart
- Props: qty, min, max, onChanged
- 32×32px buttons, number centered
- + filled biru, − outline

### 7. `_GantiTipeOrderConfirmDialog` — dialog konfirmasi ganti tipe
- "Tipe Order Berbeda"
- Info: "Toko ini menggunakan {tipeBaru}. Produk {tipeLama} di keranjang akan dihapus."
- Box warning: "N item ({tipeLama}) akan dihapus"
- [Tetap] [Ganti & Hapus] (merah)

---

## Progress Bar Design

- Position: di atas info toko (header → progress → toko → produk)
- Connector: biru untuk yang sudah dilewati & ke step aktif
- Connector: abu untuk yang belum dicapai
- Step circle: biru untuk sudah/lalu
- Step aktif: biru + shadow ring
- Step belum: outline abu

---

## Detail UI

### Warna (dari design_system.dart)
- Primary: `#1E3A5F` (navy)
- Primary Light: `#2563EB` (electric blue) — CTA
- Success: `#059669` — diskon, gratis, savings
- Error: `#DC2626` — hapus, cancel
- Background: `#F4F7FB`
- Card surface: `#FFFFFF`
- Text primary: `#0F172A`
- Text secondary: `#475569`
- Text muted: `#94A3B8`
- Border: `#E2E8F0`

### Spacing
- Card padding: 14px
- Card radius: 12px
- Horizontal margin: 16px
- Gap antar section: 8px
- Action button height: 36px (dalam card), 44px (bottom bar)

### Typography
- Section title: bodyMedium w700, textSecondary
- Product name: bodyMedium w600, textPrimary
- Price: headlineSmall w700, primaryLight
- Discount: bodySmall w600, success
- Meta (qty×price): bodySmall, textMuted

---

## Verifikasi

1. Buka app → Order Baru → pilih toko → pilih tipe → tambah produk → review
2. Cek: card produk terlihat lebih lega, nama tidak terpotong
3. Cek: stepper mudah diketuk (min 44px touch target)
4. Tap "Diskon" → bottom sheet muncul dengan benar
5. Masukkan diskon → subtotal berubah
6. Tap "Simpan" → sheet tutup, summary diskon muncul di card
7. Tap "Gratis" → bottom sheet promo gratis muncul
8. Tambah gratis item → card baru muncul dengan label GRATIS
9. Tap "×" di card → item dihapus
10. Tap ← (back) → langsung ke step Produk
11. Tap "Batal" → dialog konfirmasi muncul
12. Ganti toko → kembali ke step toko
13. Ganti tipe order (REGULER→4P) → dialog warning + hapus keranjang
