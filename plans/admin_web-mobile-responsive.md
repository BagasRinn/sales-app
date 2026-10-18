# admin_web — Mobile Responsive Plan

> Plan ini menjelaskan langkah-langkah untuk membuat `sales-app/admin_web` (Flutter web admin dashboard) nyaman dipakai di **Desktop Web**, **Mobile Web (Android/iOS, portrait/landscape)**, dan **Tablet (Android/iOS, portrait/landscape)** — dengan fungsionalitas 100% sama, UI/UX lebih baik, dan konsistensi tinggi via reusable component.

**Tanggal:** 2026-10-14
**Scope:** `sales-app/admin_web/lib/**`
**Backend:** TIDAK BERUBAH (API shape frozen).
**Git:** User commit manual — plan ini tidak menyertakan langkah git.

---

## 0. Keputusan User (locked in)

| # | Topik | Keputusan |
|---|---|---|
| 1 | `_UserEditDialog` di compact | **Fix pakai scroll dulu.** Full-screen page hanya fallback kalau scroll terbukti tidak efektif. |
| 2 | Navigation compact | **Drawer saja dulu.** Tidak tambah `BottomNavigationBar` di Phase 1. |
| 3 | Idle-logout mobile | **Apply touch-event override** supaya mobile tidak logout saat user baca tanpa interaksi 5 menit. |
| 4 | Phase scope | **HIGH dulu** (9 item) → setelah aman → MEDIUM (17) → LOW (10). |

**Execution rules:**
- Pertahap: 1 phase = 1 commit (user commit manual).
- Test per fase di dev server (`flutter run -d chrome`), bukan batched di akhir.
- Setiap fase harus ada summary: file berubah/baru, perubahan visual ya/tidak, langkah verifikasi spesifik.

---

## 1. Ringkasan & Tujuan

`admin_web` adalah Flutter Web app untuk admin/manager/supervisor sales yang mengakses backend REST (Dio + JWT) lewat dashboard dengan 10+ tab: **Dashboard (Stats)**, **Pesanan**, **Toko (Customers)**, **Produk & Stok**, **Sinkronisasi**, **User Management**, **Performa Sales**, **Penugasan Sales**, **Bulletin (Pengumuman)**, **Pengajuan Customer**, dan **Laporan Lintas Cabang** (MANAGER only). Saat ini shell sudah responsive (sidebar 240px di desktop, drawer di compact via `Responsive` helper di `lib/core/responsive.dart`), tetapi **konten di tiap tab dan dialog di dalamnya masih banyak yang hard-coded** untuk desktop: tabel 12 kolom, dialog `SizedBox(width: 960, height: 600)`, `IconButton` touch target < 40px, dan tabel Flutter `Table`/`DataTable` yang tidak bisa di-scroll horizontal di layar kecil. Hasilnya, di iPhone / Android (lebar 360–430px) banyak konten overflow, terpotong, atau dialog menutupi layar tanpa bisa di-scroll.

**Tujuan plan ini:**
1. Mendefinisikan ulang **breakpoint, layout strategy, dan design tokens** (typography/spacing) yang konsisten lintas device.
2. Membentuk **reusable component library** (responsive dialog, responsive table, empty/loading/error state, dsb.) sehingga tiap tab tidak menulis ulang pola yang sama.
3. Mengadaptasi **setiap screen dan dialog** ke 3 mode (compact < 600 / medium 600–1024 / expanded > 1024) — fungsionalitas sama, layout adaptif.
4. Memperbaiki **touch target**, **dialog scrollability**, **table → card fallback** untuk layar kecil, dan **typography** yang menghormati OS text-scale.
5. Menyediakan **test plan manual + otomatis** agar kualitas di tiap device bisa diverifikasi sebelum release.

**Outcome yang diharapkan:** admin/supervisor bisa menjalankan seluruh workflow (login → review pesanan → approve/reject → ubah diskon → assign sales → unduh laporan) di **iPhone Safari** maupun **iPad Safari** tanpa konten terpotong, tanpa harus bolak-balik zoom, dan tanpa kehilangan fungsionalitas apa pun.

---

## 2. Target Responsive Design System

### 2.1 Breakpoints

Sudah ada di `lib/core/responsive.dart` (`Breakpoints.mobileMax = 600`, `Breakpoints.tabletMax = 1024`). Plan ini **memperkuat dan menstandarkan** zona yang dipakai seluruh tim:

| Zona | Lebar | Device Target | Layout Density | Primary Nav |
|---|---|---|---|---|
| **Compact** | `< 600px` | iPhone (SE/13/14/15, 360–430px), Android phone (Pixel 6/7, 360–412px) — portrait & landscape | Tight (gap 12, padding 12) | BottomNavigationBar (5 item utama) + Drawer untuk semua item |
| **Medium** | `600–1024px` | iPad Mini (768), iPad (810/834), Android tablet (800x1280), landscape phone (640–900px) | Comfortable (gap 16, padding 16) | NavigationRail (extended) di kiri + Drawer opsional |
| **Expanded** | `> 1024px` | Desktop web (1280, 1440, 1920, 2560) | Spacious (gap 16, padding 24) | Sidebar tetap 240px |

**Perubahan konkret:**
- `lib/core/responsive.dart` → rename zona agar konsisten dengan Flutter convention: `compact` / `medium` / `expanded` (saat ini: `mobile` / `tablet` / `desktop`). Tetap expose alias lama (`isMobile`/`isTablet`/`isDesktop`/`isCompact`) supaya **tidak ada satu pun screen yang perlu di-update namanya di fase ini**.
- Tambahkan konstanta `Breakpoints.compactMax = 600`, `Breakpoints.mediumMax = 1024` (sudah ada), dan helper `DeviceClass.compact/medium/expanded` (alias untuk `mobile/tablet/desktop`).
- Shell (`lib/presentation/screens/dashboard_screen.dart`): pada compact, tambahkan `BottomNavigationBar` untuk 5 item paling sering dipakai (Stats, Pesanan, Toko, Produk, Sinkronisasi); item lain tetap via Drawer. Pada medium, pakai `NavigationRail.extended`. Pada expanded, tetap sidebar 240px.

### 2.2 Layout Strategy

Bagaimana tiap pola UI utama beradaptasi:

| Pola | Compact | Medium | Expanded |
|---|---|---|---|
| **Master / Detail** (e.g. Pesanan list → detail) | Tap-to-push full screen dengan `Navigator.push` (sudah ada pola `_SubmissionDetailScreen` di `customer_submissions_tab.dart` — adopsi). | Sama seperti compact; atau side-by-side 40/60 jika lebar ≥ 900. | Side-by-side 35/65 ataukan dialog center. |
| **Tab Navigation** (Pesanan "Menunggu / Semua", Bulletin "Semua / Kadaluarsa") | `TabBar(isScrollable: true)` dengan label ringkas; jika 2 tab saja, pakai `SegmentedButton` (lebih ringkas di mobile). | `TabBar` biasa. | `TabBar` biasa. |
| **Sidebar / Navigation** | Drawer (slide dari kiri) + BottomNavigationBar untuk quick access. | `NavigationRail.extended` (label selalu tampil, 80px). | Sidebar 240px (sudah ada). |
| **Forms** | Single column, label di atas field, full-width input, `TextField` 56px tinggi, helper text di bawah. | 1–2 column via `IntrinsicHeight` + `Row` (2 fields per baris). | 2 column dengan label di kiri (kiri-kanan) untuk form panjang. |
| **Data Tables** | **Card list fallback** (satu record = satu `Card` dengan label-value grid 2 kolom). | Table ringkas (≤ 6 kolom) dengan horizontal scroll, atau card list jika > 6 kolom. | Full table (semua kolom, lebar optimal). |
| **Cards / Lists** | 1 card per baris, padding 12, gap 12. | 2 card per baris (Wrap), padding 16, gap 16. | 2–3 card per baris, padding 24, gap 16. |
| **FAB (Floating Action Button)** | `FloatingActionButton` mini (icon only, 48x48), label disembunyikan, ada tooltip. | Extended (icon + label) jika cukup ruang; mini jika crowded. | Extended. |
| **Filter Bar** (search + dropdown + chip) | Stack vertikal: search full-width di atas, dropdown/chip di bawah. | Search + filter chips di satu baris (bisa wrap). | Search + filter chips di satu baris dengan ample space. |

### 2.3 Dialog & Bottom Sheet Strategy

**Aturan pemilihan container:**

| Use Case | Compact | Medium | Expanded |
|---|---|---|---|
| **Konfirmasi kecil** (ya/tidak, hapus) | `showModalBottomSheet` (Material 3 default) dengan `isScrollControlled: false` dan `showDragHandle: true`. | `showDialog` dengan `ResponsiveAlertDialog` (centered, max 480x420). | `ResponsiveAlertDialog` centered. |
| **Form pendek** (1–2 field) | Bottom sheet dengan `SingleChildScrollView` (bukan dialog) — keyboard tidak menutupi tombol. | `ResponsiveAlertDialog` max 640x520. | `ResponsiveAlertDialog`. |
| **Form panjang / multi-step** (User edit, Customer edit) | **Full-screen page push** (route baru dengan `AppBar` + Save di kanan). | Full-screen page atau `ResponsiveDialog` full-height. | `ResponsiveDialog` 960x600. |
| **Detail besar** (Sales detail overlay, Submission detail) | **Full-screen push** (sudah dipakai `_SubmissionDetailScreen`). | `ResponsiveDialog` 90% viewport. | `ResponsiveDialog` 960x600. |
| **Picker / date range** | Native bottom sheet picker (Flutter `showDatePicker` sudah cukup mobile-friendly, hanya perlu override `builder` untuk atur max width — lihat isu di `orders_tab.dart:136-156`). | Sama. | Sama. |

**Dialog yang perlu di-refactor (dari inventaris):**
- **HIGH**: `lib/presentation/screens/performance_tab.dart:748-808` (target set dialog dengan `SizedBox(width: 360)`) → migrate ke `ResponsiveAlertDialog`.
- **HIGH**: `lib/presentation/screens/users_tab.dart` (`_UserEditDialog`) → tambahkan `SingleChildScrollView` di body.
- **MEDIUM**: `lib/presentation/screens/stats_tab.dart:1820-1860` (`_SalesDetailDialogBody` punya `SizedBox(width: 960, height: 600)` hard-coded) → hapus SizedBox, biarkan `ResponsiveDialog` parent yang mengatur ukuran.
- **MEDIUM**: `lib/presentation/screens/stats_tab.dart:355-470` (3 helper `_openTotalDetail`/`_openBranchDetail`/`_openSalesDetail` pakai `Dialog(insetPadding: EdgeInsets.all(32))` raw) → pakai `ResponsiveDialog` helper secara langsung.
- **MEDIUM**: `lib/presentation/screens/change_password_dialog.dart` (Column non-scrolling) → bungkus body dengan `SingleChildScrollView`.
- **MEDIUM**: `lib/presentation/screens/customer_submissions_tab.dart:893,994` (approve + reject dialog, non-scrolling) → `SingleChildScrollView` atau konversi ke bottom sheet di compact.
- **MEDIUM**: `lib/presentation/screens/orders_tab.dart:542,622` (approve + reject, Row tombol tanpa scroll) → `ResponsiveAlertDialog`.
- **LOW**: `lib/presentation/screens/bulletins_tab.dart:328` (delete confirm raw `AlertDialog`) → migrate ke `ResponsiveAlertDialog`.

### 2.4 Typography & Spacing

**Tokens sudah ada di `lib/core/design_system.dart` (`AppTextStyles`).** Plan ini memperkaya:

- **Tambah variants** di `AppTextStyles`:
  - `labelMedium` (12, w500) — untuk label section / chip.
  - `labelSmall` (11, w600) — untuk badge kecil (Read-only, status).
  - `titleLarge` (16, w700) — untuk section header di dalam card.
  - `bodySmall` (sudah ada) — untuk metadata, dengan tambahan `color: AppColors.textMuted`.
  - `caption` (10, w400) — untuk timestamp / footnote, hanya dipakai di label non-interaktif.

- **Pakai `Theme.of(context).textTheme.*`** sebagai canonical source di widget baru; konstanta `AppTextStyles.*` tetap dipakai untuk ad-hoc styling di luar `Text` (mis. `TextStyle` di `Container.decoration`).
- **OS text-scale** harus dihormati di mobile: setiap `Text` baru yang ditulis ulang di fase ini **tidak boleh** hard-code `fontSize`/`textScaler`; pakai `Theme.of(context).textTheme.*` yang otomatis scale.

- **Spacing tokens** (di `lib/core/responsive.dart` via `ResponsiveSpacing`):
  - `gap` (antar elemen): compact 12 / medium 16 / expanded 16.
  - `sectionGap` (antar section): compact 16 / medium 24 / expanded 24.
  - `contentPadding` (page padding): compact 12 / medium 16 / expanded 24 (sudah ada).
  - **Tambah**: `cardPadding` (12/16/20), `dialogPadding` (16/20/24), `formGap` (16/16/20) sebagai konstanta di `Responsive`.

---

## 3. Reusable Component Library

Setiap komponen = 1 file di `lib/presentation/widgets/`. File yang **benar-benar dipakai** oleh ≥ 2 screen layak masuk sini; komponen one-off tetap inline.

| # | Nama | File (suggested) | Purpose | Key Props | Used By |
|---|---|---|---|---|---|
| 1 | `ResponsiveHelper` (alias `Responsive` sudah ada) | `lib/core/responsive.dart` | Breakpoint, padding, gap, sidebar width, top bar height. | `Responsive.of(width)`, `isCompact`/`isMedium`/`isExpanded` | Semua screen (sebagai dependency, bukan dipakai langsung). |
| 2 | `ResponsiveDialog` (sudah ada) | `lib/core/responsive_dialog.dart` | Dialog wrapper — full-screen di compact, 960x600 di expanded. | `child`, `maxWidth`, `maxHeight`, `desktopWidthFraction` | 9 screen (lihat inventaris dialog). |
| 3 | `ResponsiveAlertDialog` (sudah ada) | `lib/core/responsive_dialog.dart` | AlertDialog-style — title row, scrollable content, stacked actions di compact. | `title`, `content`, `actions`, `contentMaxWidth` | 8 screen. |
| 4 | `ResponsiveBottomSheet` (BARU) | `lib/presentation/widgets/responsive_bottom_sheet.dart` | Wrapper `showModalBottomSheet` yang otomatis full-height di compact dan centered modal di expanded. | `child`, `title`, `actions`, `isScrollControlled` | `change_password_dialog.dart` (mobile), `customer_submissions_tab.dart` (approve/reject di mobile), `orders_tab.dart` (approve/reject di mobile), semua konfirmasi di mobile. |
| 5 | `ResponsiveTable<T>` (BARU) | `lib/presentation/widgets/responsive_table.dart` | Widget generik: tampil sebagai `DataTable`/`Table` di medium/expanded, sebagai **card list** di compact. | `columns: List<ColumnSpec<T>>` (label, value extractor, isAction), `rows: List<T>`, `actions: List<RowAction<T>>` (id, label, icon, onTap), `onRowTap: (T) → void?` | `customers_tab.dart`, `products_tab.dart`, `users_tab.dart`, `performance_tab.dart` (supplier performance), `sync_tab.dart` (import log). |
| 6 | `ResponsiveFormLayout` (BARU) | `lib/presentation/widgets/responsive_form_layout.dart` | Wrap list of fields — single column di compact, 2 column di medium/expanded. | `fields: List<FormFieldSpec>`, `spacing` | `users_tab.dart` (`_UserEditDialog`), `customers_tab.dart` (`_CustomerDetailDialog`), `bulletins_tab.dart` (create/edit), `orders_tab.dart` (semua dialog edit). |
| 7 | `DataCard` (BARU) | `lib/presentation/widgets/data_card.dart` | Card sederhana untuk representasi 1 record di mode compact (pengganti tabel row). | `title`, `subtitle`, `badges: List<Widget>`, `fields: List<({String label, String value})>`, `actions: List<Widget>` | `customers_tab.dart`, `products_tab.dart`, `users_tab.dart`, `performance_tab.dart`. |
| 8 | `StatTile` (BARU) | `lib/presentation/widgets/stat_tile.dart` | KPI tile — label, value, optional trend/icon. Adaptif 2-kolom di compact, 3-4 kolom di medium, 4-6 kolom di expanded. | `label`, `value`, `icon?`, `color?`, `onTap?` | `stats_tab.dart`, `cross_branch_reports_tab.dart`, `customer_submissions_tab.dart` (stat cards), `orders_tab.dart` (summary chips). |
| 9 | `FilterBar` (BARU) | `lib/presentation/widgets/filter_bar.dart` | Bar yang menampung search field + filter chips + dropdowns. Stack vertikal di compact, Row wrap di medium/expanded. | `search: Widget?`, `filters: List<({Widget leading, Widget child, String? label})>`, `trailing: Widget?` | `orders_tab.dart`, `customers_tab.dart`, `products_tab.dart`, `penugasan_sales_tab.dart`, `users_tab.dart`, `performance_tab.dart`, `sync_tab.dart`. |
| 10 | `EmptyState` (BARU) | `lib/presentation/widgets/empty_state.dart` | Placeholder untuk list kosong (icon, judul, deskripsi, CTA opsional). | `icon`, `title`, `description?`, `action?` | 8+ tab (Stats empty, Orders empty, dst.). |
| 11 | `LoadingState` (BARU) | `lib/presentation/widgets/loading_state.dart` | Centered spinner + label opsional; atau skeleton shimmer untuk list. | `label?`, `useSkeleton: bool` | Semua tab (initial load). |
| 12 | `ErrorState` (BARU) | `lib/presentation/widgets/error_state.dart` | Icon error + pesan + tombol "Coba lagi". | `message`, `onRetry?` | Semua tab (load error). |
| 13 | `AppShell` (REFACTOR dari `dashboard_screen.dart`) | `lib/presentation/widgets/app_shell.dart` | Scaffold adaptif: sidebar 240 / NavigationRail / Drawer+BottomNav. | `selectedIndex`, `navItems`, `onNavTap`, `body` | `dashboard_screen.dart` (1 pemakai). |
| 14 | `PageHeader` (BARU) | `lib/presentation/widgets/page_header.dart` | Header section dalam content: judul + subjudul + action row (filter, export). | `title`, `subtitle?`, `actions: List<Widget>` | Hampir semua tab (menggantikan ad-hoc `Text` + `Row` di top content). |
| 15 | `ActionButtonRow` (BARU) | `lib/presentation/widgets/action_button_row.dart` | Row of action buttons (FilledButton/OutlinedButton) yang stack di compact, row di medium/expanded. Min height 44 per tombol. | `actions: List<({Widget label, VoidCallback? onPressed, bool primary})>`, `alignment` | Semua dialog. |
| 16 | `ConfirmDialog.show()` & `InfoDialog.show()` (BARU) | `lib/presentation/widgets/confirm_dialog.dart` | Static helper untuk dialog konfirmasi/informasi standar — otomatis pilih bottom sheet di compact, dialog di medium/expanded. | `title`, `message`, `confirmLabel`, `cancelLabel`, `isDestructive: bool` | Semua tempat `AlertDialog` confirmation dipakai (5+ tempat). |
| 17 | `ResponsiveActionMenu` (BARU) | `lib/presentation/widgets/responsive_action_menu.dart` | `PopupMenuButton` dengan 3+ action — menggantikan kumpulan `IconButton` cramped di card row. | `actions: List<({String label, IconData icon, VoidCallback onTap, bool destructive?})>`, `tooltip` | `orders_tab.dart` (Order card actions), `products_tab.dart` (row actions), `users_tab.dart` (row actions), `bulletins_tab.dart` (card actions). |
| 18 | `StatusChip` (sudah ada `StockStatusChip`/`OrderStatusChip` di `design_system.dart`) | `lib/core/design_system.dart` | Chip untuk status dengan warna token. | `status: enum`, `size: ChipSize` (small/default) | Hampir semua tab. |

**Speculative components yang DIBUANG:** draggable reorder list, custom carousel, map view, signature pad — tidak dipakai di admin_web saat ini.

---

## 4. Per-Screen Responsive Adaptations

Untuk tiap screen: apa yang berubah di **Compact** (< 600), **Medium** (600–1024), **Expanded** (> 1024), termasuk dialog/tabel/form di dalamnya. Screen yang sudah adaptif baik hanya ditandai "sudah adaptif".

### 4.1 LoginScreen — `lib/presentation/screens/login_screen.dart`
- **Compact**: card full-width minus 16px padding, padding dalam 16, tombol login 100% width, hide logo brand jika logo > 32px (atau turunkan ke 24px). `SingleChildScrollView` agar keyboard tidak menutupi tombol.
- **Medium**: card max 420px, center.
- **Expanded**: sama dengan medium.
- **Form**: `username` + `password` + `FilledButton` (sudah single column — fine).
- **Sudah adaptif** (hanya perlu minor padding tweaks).

### 4.2 DashboardScreen (shell) — `lib/presentation/screens/dashboard_screen.dart`
- **Compact**: Drawer (sudah ada) untuk SEMUA item navigasi — keputusan user, tidak tambah `BottomNavigationBar`. Top bar tinggi 56, hide "Read-only" badge ke tooltip-only.
- **Medium**: `NavigationRail.extended` di kiri (80px, label selalu tampil), tidak ada Drawer (semua item di rail).
- **Expanded**: Sidebar 240px (sudah ada).
- **Top bar**: title `headlineSmall` (18) di compact, `headlineMedium` (20) di medium/expanded.
- **Drawer width**: ganti ke `min(280, viewport * 0.85)` agar pas di iPhone SE (320px).

### 4.3 StatsTab — `lib/presentation/screens/stats_tab.dart` (3348 baris, terberat)
- **Compact**:
  - Stat card grid: 2 per baris (sudah ada di `_StatCard` dengan `LayoutBuilder` < 600) — tetap.
  - `_BranchPerformanceCard` dengan `SizedBox(width: 420)` (line 335-350) → **hapus SizedBox**, gunakan `LayoutBuilder` + `Wrap` natural width.
  - `_SalesPerformanceCard` dengan `Container(width: 340)` (line 1182-1189) → **sama, adaptif**.
  - Tombol download "Periode" (line 820-875) → full-width, dengan 4 stat tile 2x2 (50% width).
  - `_DetailRow` (line 3129-3157) dengan `SizedBox(width: 70)` label → stack label-above-value di compact.
- **Medium**: stat card 3 per baris, branch card 2 per baris (Width 420 OK), sales card 2 per baris (Width 340 OK).
- **Expanded**: sama dengan medium + 1 extra column.
- **Dialogs**:
  - `_SalesOverlayDialog` (line 1820+): **hapus `SizedBox(width: 960, height: 600)`** (line 1849-1852) — biarkan `ResponsiveDialog` parent yang atur ukuran. Pada compact, body tetap pakai `_SalesDetailDialogBody` mode compact (sudah ada branching `resp.isMobile`). Pada medium/expanded, body mode desktop (sidebar 240 + orders right).
  - 3 helper `_openTotalDetail`/`_openBranchDetail`/`_openSalesDetail` (line 355-470) → **ganti wrapper `Dialog(insetPadding: EdgeInsets.all(32))` dengan `ResponsiveDialog` langsung** — lebih konsisten dengan 9 dialog lain.
  - Dropdown overlay di sidebar stack (line 2305-2336) → `showMenu` dengan `RelativeRect.positionedCallback` atau `OverlayPortal` agar posisi otomatis di bawah trigger.
- **Tables/lists**: stat card list, branch card list, sales card list — sudah berbasis `Wrap` + `Card`. Adaptasi width saja.
- **Forms**: report download form (date pickers) — `Wrap` di compact, `Row` di medium/expanded.

### 4.4 OrdersTab — `lib/presentation/screens/orders_tab.dart` (2131 baris)
- **Compact**:
  - TabBar `isScrollable: true` (sudah ada).
  - Search field full-width di compact (sudah single column, fine).
  - Date preset chips → `Wrap` (sudah, fine). Custom range button → label "Pilih" saja (bukan "Pilih Rentang").
  - `showDateRangePicker` builder (line 136-156): **hapus `ConstrainedBox(maxWidth: 620, maxHeight: 520)` hard-coded**, ganti `MediaQuery.size.width * 0.94`.
  - `_OrderCard` trailing Row (line 1001-1038): collapse approve/reject + delete + expand_more → `PopupMenuButton` (kebab) dengan 3 action, expand icon tetap. **Ini perbaikan touch target utama.**
  - `_OrderItemRow` (line 1455-1490): 3 IconButton dengan `minWidth: 24, minHeight: 24` → bump ke **44x44** (Material minimum) atau collapse ke `PopupMenuButton`.
  - `_buildOrderExpandedDetail` (line 2723-2805): metadata + item table — bungkus **seluruh** `Expanded` child dengan `SingleChildScrollView` (sekarang hanya item table yang scroll). Atau, pisah jadi `TabBar` kecil "Info" / "Items" di compact.
- **Medium**: `_OrderCard` bisa tampilkan 2 icon (approve, reject) di samping status chip; PopupMenu tetap untuk yang lain.
- **Expanded**: tampil seperti sekarang (3 action + expand).
- **Dialogs** (5 inline dialogs: approve, reject, discount edit, up price edit, cancel item):
  - `_DiscountEditDialog`, `_UpPriceEditDialog`, `_CancelItemDialog` sudah pakai `ResponsiveAlertDialog` dengan SingleChildScrollView → **fine**.
  - `approve` (line 542) dan `reject` (line 622) pakai `ResponsiveDialog` langsung (bukan `ResponsiveAlertDialog`), Row tombol cramped → migrate ke `ResponsiveAlertDialog` (otomatis stack di compact).
- **Tables/lists**: `_OrderCard` adalah ExpansionTile — tetap (sudah card-based).
- **Forms**: order metadata di expanded detail — sudah form-style.

### 4.5 CustomersTab — `lib/presentation/screens/customers_tab.dart` (681 baris)
- **Compact**:
  - `_buildTable` (line 171-316) — fixed-width columns + horizontal scroll → **ganti dengan card list** via `ResponsiveTable`/`DataCard`. Tiap customer = 1 card: nama (title), kode area + ID (subtitle), alamat (body), action row (Detail, Edit, Hapus).
  - Search field full-width (sudah).
  - Pagination prev/next pakai icon-only button di compact.
- **Medium**: table ringkas 5 kolom (kode, nama, kode area, aksi) dengan horizontal scroll; alamat disembunyikan atau jadi tooltip/expand.
- **Expanded**: table lengkap seperti sekarang.
- **Dialogs**:
  - `_CustomerDetailDialog` (sudah `ResponsiveDialog` + `SingleChildScrollView` body) → **fine**, kurangi padding dalam dari 24 ke 16 di compact.
  - Delete confirm (line 331) sudah `ResponsiveAlertDialog` → **fine**.
- **Tables/lists**: lihat di atas.
- **Forms**: customer edit form (TextField banyak) → `ResponsiveFormLayout` (1 col di compact, 2 col di medium+).

### 4.6 ProductsTab — `lib/presentation/screens/products_tab.dart` (982 baris)
- **Compact**:
  - Tabel 12 kolom (line 286-350) → **ganti dengan card list** via `ResponsiveTable`/`DataCard`. Card: nama produk, kategori, harga (sub), supplier + stok (chip), action menu.
  - Search + 2 dropdown filter: stack vertikal (sudah `< 400` stack, extend threshold ke `< 600`).
  - Aksi column (line 889-921) fixed 90px — **collapse 3 TextButton/IconButton ke `PopupMenuButton`**.
- **Medium**: tabel ringkas 6 kolom (kode, nama, kategori, supplier, harga, stok) — supplier disembunyikan di compact card, tampil lagi di medium.
- **Expanded**: tabel lengkap 12 kolom seperti sekarang.
- **Dialogs**:
  - Stock override (line 356) — `ResponsiveDialog` dengan Row tombol → migrate ke `ResponsiveAlertDialog` untuk konsistensi.
  - Edit product (line 497) — `ResponsiveDialog` dengan `SingleChildScrollView` body → **fine**, tambahkan `ResponsiveFormLayout` (1 col di compact).
  - Delete confirm (line 655) — `ResponsiveAlertDialog` → **fine**.
- **Tables/lists**: lihat di atas.
- **Forms**: product edit form → `ResponsiveFormLayout`.

### 4.7 SyncTab — `lib/presentation/screens/sync_tab.dart` (1104 baris)
- **Compact**:
  - Import produk + import toko cards → tetap `Wrap` 1 per baris di compact.
  - `_ResultCard` (line ~820) fixed 190px → `Wrap` natural width; atau tetap 190 dengan `Wrap` (190 < 360, jadi 1 per baris di compact, 2 di medium+).
  - Import log table (custom table dengan `_HeaderCell` fixed widths) → horizontal scroll wrapper `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
  - Error tile + import history list → card per item (sudah ListView).
- **Medium**: `Wrap` 2-3 per baris.
- **Expanded**: `Wrap` 3-4 per baris.
- **Dialogs**:
  - Clear errors confirm (line 430) sudah `ResponsiveAlertDialog` → **fine**.
  - Show errors list (line 480) sudah `ResponsiveDialog` + `Expanded` list → **fine**.
- **Tables/lists**: import log → horizontal scroll.
- **Forms**: file picker + caption → fine.

### 4.8 UsersTab — `lib/presentation/screens/users_tab.dart` (795 baris)
- **Compact**:
  - `DataTable` 6 kolom (line 240-321) → **ganti dengan card list** via `ResponsiveTable`/`DataCard`. Card: avatar + nama + @username, role chip + cabang chip, edit button.
  - ConstrainedBox(maxWidth: 1200) cap → **buka cap** di compact, pakai natural width.
  - Search + role chip filter → search full-width di atas, chip `Wrap` di bawah.
- **Medium**: `DataTable` ringkas 4 kolom (nama, role, cabang, aksi) horizontal scroll, atau card list.
- **Expanded**: `DataTable` lengkap.
- **Dialogs**:
  - `_UserEditDialog` (line 211, 331) — **HIGH PRIORITY**: Column non-scrolling dengan 3 TextField + 2 DropdownButtonFormField + SwitchListTile. Bungkus seluruh Column dengan `SingleChildScrollView` di compact; atau konversi ke **full-screen page** untuk create/edit user di compact.
  - Sudah `ResponsiveDialog` 960x600 → di compact jadi full-screen, butuh scroll.
- **Tables/lists**: lihat di atas.
- **Forms**: user edit form → `ResponsiveFormLayout` + `SingleChildScrollView`.
- **Touch target**: Edit `IconButton` 36x36 → **44x44**.

### 4.9 PerformanceTab — `lib/presentation/screens/performance_tab.dart` (890 baris)
- **Compact**:
  - `_buildPeriodFilterSection` (line 179-207) Row of 2 buttons → `Wrap` dengan spacing/runSpacing 8.
  - "Urutkan" Row (line 447-497) → `Wrap` di compact.
  - `_buildSupplierPerformanceTable` (line 254-393) Flutter `Table` (no horizontal scroll) → **wrap dengan `SingleChildScrollView(scrollDirection: Axis.horizontal)`** atau **ganti dengan card list** (satu supplier = satu card dengan KPI grid).
  - Leaderboard rows → `ListView` card (sudah, fine).
  - Target & Incentive rows: `SizedBox(width: 80)` Aksi column (line 635-644) → bump ke 100, atau ganti TextButton dengan IconButton (edit/add) di compact.
- **Medium**: table ringkas dengan horizontal scroll OK, "Urutkan" row fit.
- **Expanded**: sama seperti sekarang.
- **Dialogs**:
  - Set sales target dialog (line 740-808) — **HIGH PRIORITY**: raw `AlertDialog` dengan `SizedBox(width: 360)` hard-coded → migrate ke `ResponsiveAlertDialog` + hapus SizedBox.
  - `showSupplierTargetEditDialog` (di `lib/presentation/widgets/supplier_target_edit_dialog.dart`) sudah `ResponsiveAlertDialog` → **fine**.
- **Tables/lists**: lihat di atas.
- **Forms**: short form (1 field) → fine.

### 4.10 PenugasanSalesTab — `lib/presentation/screens/penugasan_sales_tab.dart` (918 baris)
- **Compact**:
  - `SegmentedButton` (3 option: Area/Customer/Sales) — `SegmentedButton` Material 3 sudah responsive, fit. **Fine**.
  - Search field + SegmentedButton: stack vertikal (sudah ada branching `resp.isMobile`).
  - `_CustomerAssignmentRow` (line 601-624) — `TextButton.icon("Override")` cramped → `IconButton(Icons.edit)` di compact dengan tooltip.
  - `_AreaAssignmentRow` (line 382-404) — `Container(badge)` width = kodeArea length → constrain max width + ellipsis, atau `Row(mainAxisAlignment: spaceBetween)`.
- **Medium**: Row layout (sudah), `TextButton.icon` fit.
- **Expanded**: Row layout.
- **Dialogs**:
  - `_MultiSelectSalesDialog` dan `_SalesCustomersDialog` sudah `ResponsiveDialog` + `Expanded` list → **fine**.
- **Tables/lists**: row-based, fine.
- **Forms**: tidak ada form panjang.

### 4.11 BulletinsTab — `lib/presentation/screens/bulletins_tab.dart` (576 baris)
- **Compact**:
  - ListView card (sudah).
  - FAB: `resp.isCompact` → icon-only mini FAB (sudah ada branching) → **fine**.
  - `_BulletinCard` Edit + Delete `IconButton` (line 446-461) 32x32 → **44x44**.
  - Form date-picker row (line 217-251) Checkbox + label + Spacer + OutlinedButton → `Wrap` di compact.
- **Medium**: row fit.
- **Expanded**: row fit.
- **Dialogs**:
  - Create/edit bulletin (line 156) sudah `ResponsiveAlertDialog` → **fine**, tambahkan `SingleChildScrollView` di content untuk safety keyboard.
  - Delete confirm (line 328) raw `AlertDialog` → migrate ke `ResponsiveAlertDialog`.
- **Tables/lists**: card list, fine.
- **Forms**: bulletin create/edit form (judul, deskripsi, PDF, tanggal) → `ResponsiveFormLayout` 1 col.

### 4.12 CustomerSubmissionsTab — `lib/presentation/screens/customer_submissions_tab.dart` (1229 baris)
- **Compact**:
  - Filter chips (Semua/Menunggu/Disetujui/Ditolak) + 4 `_StatCard` → `Wrap` (sudah ada, fine).
  - ListView card pagination (sudah).
  - `_kvGrid` LayoutBuilder 2-col (sudah) → fine.
  - `_SubmissionDetailScreen` push full-screen (sudah) → fine.
  - `_OrderSection` (nested order items) → ExpansionTile fine.
- **Medium**: fine.
- **Expanded**: fine.
- **Dialogs**:
  - Approve (line 893): Column non-scrolling + 3 TextField + Row tombol → bungkus dengan `SingleChildScrollView` atau konversi ke `ResponsiveBottomSheet` di compact.
  - Reject (line 994): sama, lebih pendek, low risk tapi apply same fix.
- **Tables/lists**: card list, fine.
- **Forms**: approve form → `ResponsiveFormLayout` 1 col + scroll.

### 4.13 CrossBranchReportsTab — `lib/presentation/screens/cross_branch_reports_tab.dart` (299 baris)
- **Compact**:
  - TabBar Penjualan/Stok `isScrollable: true` (sudah) → fine.
  - Stat card + branch summary card list → `Wrap` adaptif.
  - **Typography fix**: ganti `Colors.white`/`Colors.black87`/`Colors.grey`/`Colors.green`/dll (line 87-300) dengan `AppColors.*` tokens.
- **Medium**: fine.
- **Expanded**: fine.
- **Dialogs**: tidak ada.
- **Tables/lists**: card list, fine.
- **Forms**: tidak ada.

### 4.14 ChangePasswordDialog — `lib/presentation/screens/change_password_dialog.dart`
- **Semua mode**: sudah `ResponsiveDialog` 960x600 → di compact jadi full-screen, fine.
- **Fix**: Column di body tanpa `SingleChildScrollView` (3 TextField + Row tombol) → tambahkan `SingleChildScrollView` agar keyboard di mobile tidak menutupi tombol.
- **Atau**: konversi ke `ResponsiveBottomSheet` di compact (lebih native di mobile).

### 4.15 LoginScreen — `lib/presentation/screens/login_screen.dart`
- Lihat 4.1 (sudah adaptif, minor tweaks).

---

## 5. Implementation Phases

### Phase 1 — Responsive Foundation (foundation utilities & tokens)

**Goal:** Semua utilitas, token, dan dialog wrapper siap dipakai ulang. **Zero visual change** di fase ini — hanya code-level prep, sehingga commit pertama bisa di-review murni sebagai foundation.

**Files affected:**
- `lib/core/responsive.dart` — tambah `Breakpoints.compactMax`/`mediumMax` aliases, `DeviceClass.compact/medium/expanded` aliases (backward compatible), `cardPadding`/`dialogPadding`/`formGap` constants, helper `Responsive.iconSize` (20/24/24).
- `lib/core/responsive_dialog.dart` — buat `ResponsiveBottomSheet` class, tambah `title`/`actions` parameters di `ResponsiveAlertDialog` (already has actions), tambah `contentMaxWidth` default diturunkan ke 360 di compact (saat ini 420).
- `lib/core/design_system.dart` — tambah `labelMedium`, `labelSmall`, `titleLarge`, `caption` di `AppTextStyles`. Tambah `AppColors.onPrimary` dll jika belum ada. (lihat section 2.4).
- `lib/core/theme.dart` — sanity check `AppTheme.lightTheme` agar `textTheme` memakai `AppTextStyles.*`.
- `lib/presentation/widgets/responsive_bottom_sheet.dart` (NEW) — wrapper bottom sheet.
- `lib/presentation/widgets/responsive_action_menu.dart` (NEW) — `PopupMenuButton` generic.
- `lib/presentation/widgets/loading_state.dart` (NEW), `empty_state.dart` (NEW), `error_state.dart` (NEW), `data_card.dart` (NEW), `stat_tile.dart` (NEW), `filter_bar.dart` (NEW), `page_header.dart` (NEW), `action_button_row.dart` (NEW), `confirm_dialog.dart` (NEW).

**Done when:**
- `flutter analyze` lulus tanpa warning baru.
- Existing screens **tidak berubah** secara visual (semua perubahan additive, bukan breaking).
- `Responsive.of(width).isCompact` dan `isMedium`/`isExpanded` bisa dipanggil di mana-mana.

---

### Phase 2 — Reusable Component Hardening (validasi di 2 screen dulu)

**Goal:** Komponen reusable dipakai di 2 pilot screen (StatsTab + OrdersTab) sebagai validasi. Setelah itu, adopsi ke semua screen lain.

**Files affected:**
- `lib/presentation/widgets/responsive_table.dart` (NEW) — generic table/card switcher.
- `lib/presentation/widgets/responsive_form_layout.dart` (NEW) — single/multi column form.
- `lib/presentation/widgets/app_shell.dart` (NEW) — extract dari `dashboard_screen.dart` (scaffold + nav adaptif).
- `lib/presentation/screens/dashboard_screen.dart` — pakai `AppShell` baru. Tambah `BottomNavigationBar` (atau quick-action row) di compact.
- `lib/presentation/screens/orders_tab.dart` — pakai `ResponsiveTable` (untuk order card list di compact), `ResponsiveActionMenu` (untuk order card trailing), `StatTile` (untuk summary chips).
- `lib/presentation/screens/stats_tab.dart` — pakai `StatTile` (untuk stat cards), `DataCard` (untuk branch/sales performance card di compact), `ResponsiveDialog` langsung (drop wrapper Dialog manual).

**Done when:**
- 2 pilot screen (`orders_tab.dart` + `stats_tab.dart`) berjalan tanpa overflow di `flutter run -d chrome --web-port=8080` dengan viewport 360x800.
- Touch target minimum 44x44 di seluruh interactive widget.
- Dialog yang sebelumnya raw `AlertDialog`/`Dialog` sudah di-migrate ke `ResponsiveAlertDialog`/`ResponsiveDialog`.
- Code review: tidak ada `SizedBox(width: <some hardcoded>)` untuk outer container lagi.

---

### Phase 3 — Per-Screen Adaptation (sisa screen)

**Goal:** Semua screen lain mengadopsi pattern dari Phase 2.

**Files affected (urutan eksekusi disarankan):**
1. `lib/presentation/screens/customers_tab.dart` — `ResponsiveTable` (table → card list), `DataCard`, `FilterBar`.
2. `lib/presentation/screens/products_tab.dart` — `ResponsiveTable`, `DataCard`, `ResponsiveActionMenu` (Aksi 3 tombol → 1 menu).
3. `lib/presentation/screens/users_tab.dart` — `ResponsiveTable` (DataTable → card list), `_UserEditDialog` fix scroll.
4. `lib/presentation/screens/performance_tab.dart` — `ResponsiveTable` (Table → card list atau horizontal scroll), `ResponsiveAlertDialog` (target set dialog), `Wrap` (filter section).
5. `lib/presentation/screens/sync_tab.dart` — `DataCard` untuk sync result, `ResponsiveTable` untuk import log.
6. `lib/presentation/screens/penugasan_sales_tab.dart` — `DataCard` untuk customer/area row, `IconButton` replace `TextButton.icon` di compact.
7. `lib/presentation/screens/bulletins_tab.dart` — touch target 44x44, `ResponsiveAlertDialog` (delete confirm), `Wrap` (date picker).
8. `lib/presentation/screens/customer_submissions_tab.dart` — `ResponsiveBottomSheet` (approve/reject di compact), `SingleChildScrollView` di body dialog.
9. `lib/presentation/screens/change_password_dialog.dart` — `SingleChildScrollView` body atau `ResponsiveBottomSheet`.
10. `lib/presentation/screens/cross_branch_reports_tab.dart` — ganti `Colors.*` ke `AppColors.*`.
11. `lib/presentation/screens/login_screen.dart` — minor padding tweak.
12. `lib/presentation/widgets/supplier_target_edit_dialog.dart` — sanity check `ResponsiveAlertDialog` usage (sudah fine).

**Done when:**
- Semua 13 screen di atas lulus visual review di compact (360px) tanpa overflow.
- Tidak ada raw `AlertDialog` (semua pakai `ResponsiveAlertDialog`).
- Tidak ada raw `Dialog(insetPadding: ...)` wrapper manual (semua lewat `ResponsiveDialog`).
- Touch target minimum 44x44 di semua `IconButton` interactive.

---

### Phase 4 — Polish & Test (validasi menyeluruh)

**Goal:** Visual polish, accessibility, performance, dan validasi di device matrix.

**Files affected:**
- `lib/core/design_system.dart` — finalisasi token (typography scale, spacing).
- `lib/presentation/widgets/*.dart` — bug fixes dari feedback Phase 3.
- `test/widgets/` (NEW) — golden tests untuk `ResponsiveDialog`, `ResponsiveTable`, `StatTile`, `DataCard`, `EmptyState` di 3 breakpoint.
- `test/screens/` (NEW) — widget tests untuk pilot screens (StatsTab, OrdersTab) dengan `TestWidgetsFlutterBinding`.

**Done when:**
- Manual test pass di device matrix (lihat section 6.1).
- Golden tests pass untuk semua komponen.
- `flutter run -d chrome` di 360x800 tanpa horizontal page scroll.
- Lighthouse mobile score ≥ 90 (jika applicable).

---

## 6. Testing Strategy

### 6.1 Device Matrix (manual test)

| Device | Viewport | Orientation | Yang Diverifikasi |
|---|---|---|---|
| iPhone SE (1st gen) | 320x568 | Portrait | Login, Drawer open, Orders list, Order detail, Order dialog (approve/reject/discount), Customers card list, Products card list, Stats stat tiles. |
| iPhone 13/14 | 390x844 | Portrait | Semua flow + bottom navigation (jika dipakai). |
| iPhone 14 Pro Max | 430x932 | Portrait | Sama, plus dialog responsive penuh. |
| iPhone 14 | 390x844 | Landscape (844x390) | Sidebar (jika ada) + content side-by-side. Bottom nav berubah jadi rail? |
| Pixel 6/7 | 412x915 | Portrait | Sama dengan iPhone 13. |
| Pixel 7 | 915x412 | Landscape | Sama dengan iPhone landscape. |
| iPad Mini | 768x1024 | Portrait | NavigationRail extended, table ringkas. |
| iPad | 810x1080 / 834x1194 | Portrait/Landscape | Layout 2-column di Stats, table 6 kolom. |
| Desktop Chrome | 1280x800 | Landscape | Sidebar 240, table penuh, dialog 960x600 centered. |
| Desktop Wide | 1920x1080 | Landscape | Sama, content max 1600. |
| Desktop Ultrawide | 2560x1440 | Landscape | Cap content max 1800, center. |

**Per device, cek checklist:**
1. Login screen tampil tanpa overflow saat keyboard muncul.
2. Drawer/Rail/BottomNav bisa dibuka dan menavigasi.
3. Semua tab dapat di-load tanpa error.
4. List/scroll tidak ada horizontal page scroll.
5. Tap pada tombol/IconButton tidak meleset (touch target ≥ 44x48).
6. Dialog form: keyboard tidak menutupi tombol Save/Cancel.
7. Table → card fallback menampilkan semua kolom.
8. Tidak ada `RenderFlex overflowed` warning di console.

### 6.2 Automated Tests

**Widget tests (NEW, di `test/widgets/`):**
- `responsive_dialog_test.dart` — golden test 3 breakpoint: compact (full-screen, no radius), medium (600x520), expanded (960x600 centered).
- `responsive_table_test.dart` — golden test dengan mock data: 3 breakpoint, ensure card list di compact, table di expanded.
- `stat_tile_test.dart` — golden test 3 breakpoint.
- `data_card_test.dart` — golden test dengan mock fields + actions.
- `empty_state_test.dart`, `loading_state_test.dart`, `error_state_test.dart` — golden test.

**Screen tests (NEW, di `test/screens/`):**
- `orders_tab_compact_test.dart` — pump dengan `TestWidgetsFlutterBinding` + size 360x800; ensure `_OrderCard` PopupMenuButton tampil, bukan 3 icon cramped.
- `users_tab_dialog_test.dart` — `_UserEditDialog` di compact: ensure scroll muncul saat keyboard up.
- `stats_tab_overflow_test.dart` — `StatsTab` di 360x800: ensure tidak ada `RenderFlex overflowed`.

**Integration test (optional):**
- `integration_test/admin_smoke_test.dart` — login → navigate ke OrdersTab → tap card → tap approve dialog → assert dialog tampil di responsive layout.

### 6.3 Build & Run Commands

```bash
# Desktop web
cd sales-app/admin_web
flutter run -d chrome

# Specific viewport (Chrome devtools, atau pakai flag --web-renderer html)
flutter run -d chrome --web-renderer html

# Build production
flutter build web --release

# Test di device matrix (gunakan browser responsive mode)
# Chrome DevTools → Toggle Device Toolbar → pilih iPhone 13 / iPad / dst.

# Run widget tests
flutter test

# Run golden tests (regenerate jika UI berubah)
flutter test --update-goldens

# Analisis statis
flutter analyze

# Format
dart format lib/ test/
```

**Untuk test mobile Safari/iOS Safari spesifik** (jika user punya akses):
- Build web → serve di `localhost:8080` → buka dari Safari iOS di device yang sama (via network IP).
- Atau gunakan BrowserStack / Sauce Labs untuk matrix.

---

## 7. Risks & Open Questions

1. **`_UserEditDialog` complexity:** **Keputusan user**: fix pakai scroll dulu (wrap body Column dengan `SingleChildScrollView` di compact). Full-screen page (Opsi B) hanya dipakai kalau setelah implementasi scroll tombol Save/Cancel masih susah dijangkau atau keyboard masih menutupi field. Verifikasi setelah fase 2.

2. **Table-to-card fallback fidelity:** `ResponsiveTable` untuk `customers_tab`/`products_tab`/`users_tab`/`performance_tab` menampilkan data yang sama dalam 2 bentuk. **Trade-off**: card list bisa lebih panjang per item (scroll lebih banyak) tapi readability di mobile lebih baik. **Open question**: untuk `products_tab` (12 kolom) dan `users_tab` (6 kolom), apakah ada kolom yang **tidak perlu** tampil di card list (mis. `created_at`)? Default: tampilkan semua, dengan field yang jarang dilihat di-collapse ke expansion.

3. **BottomNavigationBar vs Drawer di compact:** **Keputusan user**: Drawer saja dulu, tidak tambah `BottomNavigationBar`. Item navigasi tetap di Drawer hamburger. Jika setelah Phase 2/3 user merasa nav terlalu dalam, bisa di-revisit di iterasi berikut.

4. **Backend pagination shape:** Inventory menyebutkan "Backend API shape is FROZEN". Mobile responsive TIDAK mengubah request/response — hanya mengubah rendering. **No risk di sini**, hanya konfirmasi.

5. **Hard-coded sizes yang intentional:** Logo brand, avatar (CircleAvatar radius 18, 22, dst.) — tidak akan diubah. Hanya `SizedBox(width: 420)`/`width: 340`/`width: 360` yang konteksnya **container** (bukan element dekoratif) yang akan di-refactor.

6. **Cross-tab state preservation:** Saat user di OrderCard (expanded), lalu rotate phone atau ubah viewport (resize browser) — apakah state ExpansionTile harus di-reset? Default Flutter: state di-key dengan posisi di tree, jadi resize horizontal **tidak** reset state. Verified OK.

7. **Performance impact:** `ResponsiveTable` di compact merender card list, bukan table — bisa lebih banyak widget. Untuk dataset kecil (≤ 100 baris per page) tidak masalah. AdminProvider sudah pakai client-side pagination, jadi dataset per page terbatas. **No risk** untuk skala data saat ini.

8. **Idle-logout timer:** Ada wiring idle-logout di `dashboard_screen.dart` (lihat inventaris). Mobile browser di background tab bisa trigger logout karena dianggap idle. **Open question**: perlu override idle detection untuk mobile (touch event)? Saran: track touch events sebagai "active" supaya mobile tidak logout saat user baca data tanpa interaksi 5 menit. Diskusi terpisah.

9. **PDF picker (bulletins_tab):** `pickPdfFile` web implementation pakai `dart:html` (deprecated di Flutter 3.27+). Saat ini Flutter web masih support, tapi untuk masa depan perlu migrasi ke `package:web` (sudah ada di pubspec). **Out of scope** plan ini, tapi worth noting.

10. **Date range picker overflow** di `orders_tab.dart:136-156` — fix straightforward (lihat section 4.4), tapi mungkin muncul di screen lain yang juga pakai `showDateRangePicker` (cek `stats_tab.dart` untuk report download). **Apply same fix** ke semua site.

---

## 8. Out of Scope

Plan ini **TIDAK** mencakup:

1. **Backend changes** — API shape frozen. Tidak ada endpoint baru, tidak ada perubahan payload request/response.
2. **Feature additions** — tidak menambah fitur bisnis baru (mis. push notification, offline mode, dark mode, dark theme).
3. **Dark mode / theme redesign** — `AppTheme.lightTheme` tetap; tokens typography/spacing ditambah, tapi **tidak** dibuat dark mode di plan ini.
4. **Localization (i18n)** — semua string tetap hard-coded Bahasa Indonesia. Tidak抽取 ke `intl`/`arb`.
5. **Native mobile wrapper** — tidak ada Capacitor/Flutter mobile build. Plan ini fokus ke **Flutter Web di mobile browser**. (User bisa wrap jadi PWA di iterasi berikut.)
6. **State management migration** — `AdminProvider` (ChangeNotifier) tetap; tidak migrasi ke Riverpod/Bloc.
7. **Router migration** — Navigator 1.0 tetap; tidak migrasi ke GoRouter/Router 2.0.
8. **PDF picker migration** ke `package:web` (lihat risk #9).
9. **Refactor `dashboard_screen.dart` ke AppShell** untuk mengurangi 771 baris (lihat Phase 2) — dilakukan **separuh** (extract AppShell), bukan full decomposition.
10. **Stat tile animations, chart sparklines, fancy transitions** — minimal animation (subtle fade-in only).
11. **Accessibility audit (full WCAG 2.1 AA)** — touch target 44x44 dan OS text-scale dihormati, tapi tidak ada full a11y audit (color contrast di semua kombinasi status, screen reader labels lengkap, focus management di dialog). Disarankan audit terpisah.
12. **Performance profiling** (bundle size, paint timing) — tidak diukur di plan ini; Lighthouse opsional.
13. **Migration ke Flutter 4.x / Dart 3.7+** — fokus di codebase saat ini.
14. **Git commits, PR, branch management** — user commit manual.
15. **Idle-logout tuning untuk mobile** (lihat risk #8) — diskusi terpisah.

---

## Lampiran A — Inventaris High-Priority Fix (dari analisis)

Dipindahkan ke sini agar mudah di-tracker:

| # | File | Line | Severity | Ringkasan Fix |
|---|---|---|---|---|
| 1 | `lib/presentation/screens/performance_tab.dart` | 748-808 | HIGH | Replace raw `AlertDialog` + `SizedBox(width: 360)` dengan `ResponsiveAlertDialog`. |
| 2 | `lib/presentation/screens/users_tab.dart` | 211, 331 | HIGH | `_UserEditDialog` body butuh `SingleChildScrollView` agar tidak overflow di compact. |
| 3 | `lib/presentation/screens/stats_tab.dart` | 1849-1852 | HIGH | Hapus `SizedBox(width: 960, height: 600)` di `_SalesDetailDialogBody` — biarkan parent yang atur. |
| 4 | `lib/presentation/screens/orders_tab.dart` | 1455-1490 | HIGH | `_OrderItemRow` 3 IconButton min 24x24 → 44x44 atau collapse ke `PopupMenuButton`. |
| 5 | `lib/presentation/screens/orders_tab.dart` | 1001-1038 | HIGH | `_OrderCard` trailing Row cramped → `PopupMenuButton` di compact. |
| 6 | `lib/presentation/screens/orders_tab.dart` | 136-156 | MEDIUM | `showDateRangePicker` builder — hapus `ConstrainedBox(maxWidth: 620, maxHeight: 520)`. |
| 7 | `lib/presentation/screens/products_tab.dart` | 889-921 | HIGH | Aksi 3 kontrol cramped 90px → `PopupMenuButton`. |
| 8 | `lib/presentation/screens/products_tab.dart` | 286-350 | MEDIUM | 11-col table 1490px → card list di compact. |
| 9 | `lib/presentation/screens/users_tab.dart` | 240-321 | MEDIUM | DataTable 6-col → card list di compact. |
| 10 | `lib/presentation/screens/users_tab.dart` | 298-316 | MEDIUM | Edit IconButton 36x36 → 44x44. |
| 11 | `lib/presentation/screens/customers_tab.dart` | 171-316 | MEDIUM | Customer table fixed col → card list di compact. |
| 12 | `lib/presentation/screens/performance_tab.dart` | 254-393 | HIGH | `Table` widget (no horizontal scroll) → `SingleChildScrollView` atau card list. |
| 13 | `lib/presentation/screens/performance_tab.dart` | 179-207 | MEDIUM | `_buildPeriodFilterSection` Row → `Wrap`. |
| 14 | `lib/presentation/screens/performance_tab.dart` | 447-497 | MEDIUM | "Urutkan" Row → `Wrap`. |
| 15 | `lib/presentation/screens/performance_tab.dart` | 635-644 | MEDIUM | `_TargetSection` Aksi 80px → 100 atau IconButton. |
| 16 | `lib/presentation/screens/stats_tab.dart` | 335-350 | HIGH | `_BranchPerformanceCard` `SizedBox(width: 420)` → adaptif. |
| 17 | `lib/presentation/screens/stats_tab.dart` | 1182-1189 | HIGH | `_SalesPerformanceCard` `Container(width: 340)` → adaptif. |
| 18 | `lib/presentation/screens/stats_tab.dart` | 355-470 | LOW | 3 helper `Dialog(insetPadding: EdgeInsets.all(32))` → `ResponsiveDialog`. |
| 19 | `lib/presentation/screens/stats_tab.dart` | 2305-2336 | LOW | Dropdown overlay hardcoded `top: 100` → `showMenu` RelativeRect. |
| 20 | `lib/presentation/screens/change_password_dialog.dart` | (seluruh file) | MEDIUM | Column non-scrolling → `SingleChildScrollView` atau `ResponsiveBottomSheet`. |
| 21 | `lib/presentation/screens/customer_submissions_tab.dart` | 893, 994 | MEDIUM | Approve/reject dialog non-scrolling → scroll atau bottom sheet. |
| 22 | `lib/presentation/screens/orders_tab.dart` | 542, 622 | MEDIUM | Approve/reject pakai `ResponsiveDialog` Row tombol → `ResponsiveAlertDialog`. |
| 23 | `lib/presentation/screens/orders_tab.dart` | 2723-2805 | MEDIUM | `_buildOrderExpandedDetail` Expanded child → `SingleChildScrollView` (full). |
| 24 | `lib/presentation/screens/bulletins_tab.dart` | 328 | LOW | Delete confirm raw `AlertDialog` → `ResponsiveAlertDialog`. |
| 25 | `lib/presentation/screens/bulletins_tab.dart` | 446-461 | MEDIUM | Edit/delete IconButton 32x32 → 44x44. |
| 26 | `lib/presentation/screens/bulletins_tab.dart` | 217-251 | MEDIUM | Form date-picker Row → `Wrap`. |
| 27 | `lib/presentation/screens/penugasan_sales_tab.dart` | 601-624 | MEDIUM | `_CustomerAssignmentRow` TextButton.icon → IconButton di compact. |
| 28 | `lib/presentation/screens/penugasan_sales_tab.dart` | 382-404 | LOW | `_AreaAssignmentRow` badge width → max width + ellipsis. |
| 29 | `lib/presentation/screens/cross_branch_reports_tab.dart` | 87-300 | LOW | `Colors.*` raw → `AppColors.*` tokens. |
| 30 | `lib/presentation/screens/dashboard_screen.dart` | 413-415 | LOW | Drawer width `min(280, viewport * 0.85)`. |
| 31 | `lib/presentation/screens/dashboard_screen.dart` | 436-508 | LOW | Top bar "Read-only" badge di compact → tooltip-only IconButton. |
| 32 | `lib/presentation/screens/login_screen.dart` | 109-156 | LOW | Inner card padding 32 → 24 di compact. |
| 33 | `lib/presentation/screens/stats_tab.dart` | 3129-3157 | LOW | `_DetailRow` label `SizedBox(width: 70)` → stack label-above-value di compact. |
| 34 | `lib/presentation/screens/customers_tab.dart` | 515-545 | LOW | `_CustomerDetailDialog` padding 24 → 16 di compact. |
| 35 | `lib/presentation/screens/users_tab.dart` | 67-68 | LOW | `ConstrainedBox(maxWidth: 1200)` → buka cap di compact. |
| 36 | `lib/presentation/screens/stats_tab.dart` | 1187-1598 | LOW | Ad-hoc `fontSize: 9/10/11` → `AppTextStyles` tokens. |

**Total: 36 item**, **9 HIGH**, **17 MEDIUM**, **10 LOW**.

---

## Lampiran B — Reusable Component yang akan dibuat

| Komponen | File | Dipakai oleh (rencana) |
|---|---|---|
| `ResponsiveBottomSheet` | `lib/presentation/widgets/responsive_bottom_sheet.dart` | `change_password_dialog`, `customer_submissions_tab` (approve/reject di compact), `orders_tab` (approve/reject di compact). |
| `ResponsiveTable<T>` | `lib/presentation/widgets/responsive_table.dart` | `customers_tab`, `products_tab`, `users_tab`, `performance_tab` (supplier KPI), `sync_tab` (import log). |
| `ResponsiveFormLayout` | `lib/presentation/widgets/responsive_form_layout.dart` | `users_tab` (`_UserEditDialog`), `customers_tab` (`_CustomerDetailDialog`), `bulletins_tab`, `orders_tab` (semua dialog edit). |
| `DataCard` | `lib/presentation/widgets/data_card.dart` | `customers_tab`, `products_tab`, `users_tab`, `performance_tab`, `penugasan_sales_tab`, `sync_tab`. |
| `StatTile` | `lib/presentation/widgets/stat_tile.dart` | `stats_tab`, `cross_branch_reports_tab`, `customer_submissions_tab`, `orders_tab`. |
| `FilterBar` | `lib/presentation/widgets/filter_bar.dart` | 7 tab yang punya search/filter. |
| `EmptyState` | `lib/presentation/widgets/empty_state.dart` | 8+ tab. |
| `LoadingState` | `lib/presentation/widgets/loading_state.dart` | Semua tab. |
| `ErrorState` | `lib/presentation/widgets/error_state.dart` | Semua tab. |
| `AppShell` | `lib/presentation/widgets/app_shell.dart` | `dashboard_screen`. |
| `PageHeader` | `lib/presentation/widgets/page_header.dart` | Semua tab. |
| `ActionButtonRow` | `lib/presentation/widgets/action_button_row.dart` | Semua dialog. |
| `ConfirmDialog.show()` | `lib/presentation/widgets/confirm_dialog.dart` | 5+ confirmation sites. |
| `ResponsiveActionMenu` | `lib/presentation/widgets/responsive_action_menu.dart` | `orders_tab`, `products_tab`, `users_tab`, `bulletins_tab`. |

**Total: 14 komponen baru + 2 wrapper (Responsive/ResponsiveDialog) yang sudah ada.**

---

**End of plan.**

Kalau sudah oke dengan plan ini, kita lanjut ke **eksekusi fase 1** (responsive foundation). Bilang saja kalau ada bagian yang mau di-adjust, ditambah, atau dipotong — plan ini fleksibel dan bisa di-revisi sebelum coding.
