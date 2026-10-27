# UI/UX Safe Refactoring & Design System Guide (`design.md`)

> **CRITICAL INSTRUCTION UNTUK AI AGENT (BACA SEBELUM MENYENTUH KODE):**
> Tugas Anda adalah merombak tampilan (UI) proyek Flutter Web ini menjadi **Clean Enterprise Dashboard** dengan warna utama **Deep Navy (`#183558`)** dan **Pure White (`#FFFFFF`)** yang responsif (Desktop, Tablet, Mobile) menggunakan **Reusable Widgets**.
> **PERINGATAN KERAS:** Proyek ini sudah berjalan dengan baik secara fungsional. Anda **DILARANG KERAS** mengubah *business logic*, fungsi, alur data, *routing*, atau merusak fitur yang sudah ada. Keamanan kode dan **Zero Error** adalah prioritas tertinggi.

---

## 0. PROTOKOL BACKUP & KEAMANAN KODE (WAJIB DIEKSEKUSI PERTAMA KALI)

Sebelum membuat atau mengedit file apa pun di dalam proyek, Anda **WAJIB** menjalankan langkah pengamanan berikut di terminal:

### 0.1 Buat Backup Otomatis
1. Periksa status Git saat ini dengan `git status`.
2. Buat *branch* backup khusus dari kondisi saat ini agar kode asli aman 100%:
   ```bash
   git checkout -b backup/ui-original
   git checkout -b refactor/ui-navy-design
   ```
3. Jika proyek belum menggunakan Git, buat salinan fisik folder `lib/` terlebih dahulu:
   * Linux/macOS: `cp -r lib lib_backup_original`
   * Windows (PowerShell): `Copy-Item -Path "lib" -Destination "lib_backup_original" -Recurse`
4. **Berhenti dan laporkan ke pengguna** bahwa backup sudah berhasil dibuat sebelum lanjut ke Tahap 1.

### 0.2 Kontrak "Zero Functional Change" (Daftar yang HARAM Diubah)
Saat merombak file halaman (`*_page.dart`, `*_screen.dart`, `*_view.dart`), Anda **DILARANG** mengubah, menghapus, atau mengganti nama hal-hal berikut:
* ❌ **State & Lifecycle:** `initState()`, `dispose()`, `didChangeDependencies()`, `setState()`.
* ❌ **Controllers & Keys:** `TextEditingController`, `ScrollController`, `TabController`, `GlobalKey<FormState>`, `FocusNode`.
* ❌ **State Management & Data Streams:** Pemanggilan `Provider`, `Riverpod` (`ref.watch`/`ref.read`), `Bloc`/`Cubit` (`BlocBuilder`/`BlocListener`), `GetX` (`Obx`), `FutureBuilder`, atau `StreamBuilder`.
* ❌ **Callbacks & Validasi:** Isi fungsi `onPressed`, `onTap`, `onChanged`, `onSubmitted`, `validator`, dan fungsi pemanggilan API/Database.
* ❌ **Navigasi & Routing:** `Navigator.push/pop`, `GoRouter` (`context.go`/`context.push`), beserta seluruh parameter/`arguments` yang dikirim antar-halaman.
* ❌ **Folder Non-UI:** Jangan sentuh file di dalam folder `models/`, `services/`, `repositories/`, `providers/`, `blocs/`, `controllers/`, atau `data/`.

### 0.3 Aturan Pemetaan Widget (Cara Mengganti UI Tanpa Merusak Fungsi)
Saat mengganti widget lama ke *Reusable Widget* baru, **pindahkan seluruh properti fungsionalnya persis 1:1**:

```dart
// ❌ SEBELUM (UI Lama yang berantakan):
ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, elevation: 8),
  onPressed: _isSubmitting ? null : () => _handleSubmitOrder(context),
  child: _isSubmitting ? CircularProgressIndicator() : Text('Simpan Data'),
)

// ✅ SESUDAH (UI Baru — Fungsi, Kondisi, dan Callback 100% Tetap Sama):
AppButton(
  label: 'Simpan Data',
  isLoading: _isSubmitting,
  onPressed: _isSubmitting ? null : () => _handleSubmitOrder(context),
)
```

---

## 1. Prinsip Visual (Anti-"AI Generative" Look)

1. **Zero Surface Tint (Material 3):** Selalu set `surfaceTintColor: Colors.transparent` pada `Card`, `Dialog`, `AppBar`, dan `BottomSheet` agar warna putih (`#FFFFFF`) tidak berubah menjadi keunguan/kebiruan.
2. **Flat & Clean Border (Tanpa Shadow Tebal):** Hapus semua `elevation` tinggi (`> 2`) atau `LinearGradient` mencolok. Gunakan `Card` putih (`0xFFFFFFFF`) dengan *border* tipis `1px` (`0xFFE2E8F0`) di atas latar belakang `Scaffold` abu-abu sejuk (`0xFFF8FAFC`).
3. **Tabular Figures untuk Angka:** Semua angka metrik dan tabel wajib menggunakan `FontFeature.tabularFigures()` agar sejajar rapi.
4. **Tidak Ada Hardcode di Halaman:** Gunakan konstanta dari `AppColors`, `AppSpacing`, `AppRadius`, dan `AppTextStyles`.

---

## 2. Arsitektur Folder Komponen Baru (Aman & Non-Destruktif)

Tambahkan file sistem desain dan komponen *reusable* di dalam folder terpisah (`lib/core/design_system/`) agar **tidak menimpa file lama** sebelum proses *refactoring* selesai:

```text
lib/
└── core/
    └── design_system/
        ├── app_colors.dart          # Palet warna Deep Navy (#183558), Putih, Slate, & Status
        ├── app_tokens.dart          # AppSpacing, AppRadius, AppTextStyles
        ├── app_theme.dart           # ThemeData Material 3 global
        ├── app_responsive.dart      # Breakpoints (Mobile, Tablet, Desktop) & AppResponsiveGrid
        └── widgets/                 # REUSABLE WIDGETS (Hemat kode & konsisten)
            ├── app_shell.dart           # Adaptive Navigation (Sidebar Desktop, Rail Tablet, Drawer Mobile)
            ├── app_page_header.dart     # Header halaman (Judul, Subtitle, deretan tombol aksi)
            ├── app_card.dart            # Container putih standar dengan border 1px (#E2E8F0)
            ├── app_stat_card.dart       # Kartu KPI / Metrik ringkas
            ├── app_button.dart          # Tombol (Primary, Secondary, Outline, Ghost, Danger, Loading)
            ├── app_input.dart           # TextFormField & Dropdown dengan label di atas
            ├── app_badge.dart           # Status pill (Success, Warning, Danger, Info, Neutral)
            └── app_adaptive_table.dart  # Tabel di Desktop/Tablet -> otomatis jadi Card List di Mobile
```

---

## 3. Design Tokens (`app_colors.dart` & `app_tokens.dart`)

### 3.1 Palet Warna (`AppColors`)
```dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Primary (Deep Navy)
  static const Color primary = Color(0xFF183558);
  static const Color primaryHover = Color(0xFF122844);
  static const Color primaryLight = Color(0xFF234B7A);
  static const Color primarySoft = Color(0xFFE8EFF7);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Neutral & Surfaces (White & Slate)
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color inputBorder = Color(0xFFCBD5E1);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Semantic Status
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFEFF6FF);
}
```

### 3.2 Spacing, Radius, & Typography (`AppTokens`)
```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppRadius {
  static final BorderRadius sm = BorderRadius.circular(6.0);
  static final BorderRadius md = BorderRadius.circular(8.0);
  static final BorderRadius lg = BorderRadius.circular(12.0);
  static final BorderRadius xl = BorderRadius.circular(16.0);
}

class AppTextStyles {
  static const TextStyle metric = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13.5, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static const TextStyle bodyMuted = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted,
  );
}
```

---

## 4. Sistem Responsif Anti-Overflow (`app_responsive.dart`)

Salah satu penyebab utama error di Flutter Web saat ukuran layar diubah adalah `RenderFlex overflowed` dan `GridView` yang kaku. Gunakan `AppResponsive` dan `AppResponsiveGrid` berbasis `LayoutBuilder` + `Wrap` berikut agar **bebas error overflow di semua ukuran layar**:

```dart
import 'package:flutter/material.dart';

class AppResponsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const AppResponsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < 600;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1024;
  }
  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= 1024;

  static EdgeInsets pagePadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.all(24.0);
    if (isTablet(context)) return const EdgeInsets.all(20.0);
    return const EdgeInsets.all(16.0);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return desktop;
    if (width >= 600) return tablet ?? desktop;
    return mobile;
  }
}

/// Grid adaptif bebas overflow (menggunakan Wrap + LayoutBuilder, bukan GridView childAspectRatio)
class AppResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopCols;
  final int tabletCols;
  final int mobileCols;
  final double spacing;

  const AppResponsiveGrid({
    super.key,
    required this.children,
    this.desktopCols = 4,
    this.tabletCols = 2,
    this.mobileCols = 1,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int cols = width >= 960
            ? desktopCols
            : (width >= 540 ? tabletCols : mobileCols);

        final double itemWidth = ((width - (spacing * (cols - 1))) / cols).clamp(120.0, width);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
```

---

## 5. Spesifikasi Reusable Widgets (Kode Siap Pakai)

### 5.1 `AppCard` (`app_card.dart`)
* Menggantikan semua `Card` atau `Container` kartu lama.
* Latar `AppColors.surface` (`#FFFFFF`), border `1px` `AppColors.border` (`#E2E8F0`), `borderRadius: AppRadius.lg` (`12.0`).
* Mendukung parameter opsional `title`, `subtitle`, `trailing` (aksi di kanan atas kartu), `padding`, dan `onTap`.

### 5.2 `AppStatCard` (`app_stat_card.dart`)
* Kartu KPI dengan parameter: `title`, `value`, `icon`, `subtitle`, `trendText`, `isPositive`.
* Kotak ikon `36x36` berlatar `AppColors.primarySoft` (`#E8EFF7`) dengan ikon `AppColors.primary` (`#183558`).
* Teks `value` dibungkus `FittedBox(fit: BoxFit.scaleDown)` agar tidak pernah *overflow* di layar mobile yang sempit.

### 5.3 `AppButton` (`app_button.dart`)
* Mendukung varian: `primary` (latar `#183558`, teks putih), `secondary` (latar `#E8EFF7`, teks `#183558`), `outline` (latar putih, border `#CBD5E1`), `ghost`, dan `danger` (`#EF4444`).
* Parameter kompatibel penuh dengan tombol lama: `label`, `icon`, `onPressed`, `isLoading`, `isFullWidth`.

### 5.4 `AppInput` (`app_input.dart`)
* Membungkus `Text(label)` di atas `TextFormField` secara otomatis.
* **PENTING UNTUK KEAMANAN REFACTOR:** Wajib meneruskan seluruh parameter `TextFormField` standar (`controller`, `initialValue`, `focusNode`, `validator`, `onChanged`, `onFieldSubmitted`, `onTap`, `readOnly`, `obscureText`, `keyboardType`, `textInputAction`, `inputFormatters`, `maxLines`, `enabled`, `prefixIcon`, `suffixIcon`) agar tidak ada satupun fitur input lama yang hilang saat diganti ke `AppInput`.

### 5.5 `AppPageHeader` (`app_page_header.dart`)
* Menampilkan `title`, `subtitle` (opsional), dan `List<Widget> actions` (opsional).
* **Adaptif:** Di Desktop/Tablet menggunakan `Row` (Judul di kiri, tombol aksi di kanan). Di Mobile (`< 600px`) otomatis berubah menjadi `Column` + `Wrap` agar tombol aksi tidak menabrak judul dan tidak *overflow*.

### 5.6 `AppAdaptiveDataView` (`app_adaptive_table.dart`)
* Di layar Desktop/Tablet (`>= 600px`): Menampilkan `DataTable` bersih di dalam `AppCard` dengan header `#F8FAFC`.
* Di layar Mobile (`< 600px`): Otomatis merender daftar data sebagai `ListView.separated` berisi `AppCard` vertikal sehingga pengguna HP tidak perlu menggeser tabel ke samping.

### 5.7 Navigasi Adaptif (`AppShell`)
* **Pertahankan `selectedIndex` dan fungsi navigasi/`Router` asli proyek!**
* **Desktop (`>= 1024px`):** Sidebar tetap di kiri (`width: 256px`), latar `#183558`, item aktif berlatar `#234B7A` dengan teks/ikon putih tebal.
* **Tablet (`600px - 1023px`):** `NavigationRail` (`width: 72px`) berlatar `#183558`.
* **Mobile (`< 600px`):** Top `AppBar` putih + tombol menu yang membuka `Drawer` berlatar `#183558`.

---

## 6. Siklus Eksekusi Bertahap & Verifikasi Anti-Error (WAJIB DIIKUTI AI AGENT)

**DILARANG** merombak seluruh halaman sekaligus dalam satu langkah! Ikuti tahapan ini secara berurutan dan jalankan verifikasi di setiap tahap:

### Tahap 0: Backup (Wajib Pertama)
* Buat Git branch backup (`backup/ui-original`) atau duplikat folder `lib/`. Pastikan `flutter analyze` di kondisi awal berjalan normal.

### Tahap 1: Buat Fondasi & Reusable Widgets (Tanpa Mengubah Kode Lama)
1. Buat semua file baru di `lib/core/design_system/` (`app_colors.dart`, `app_tokens.dart`, `app_theme.dart`, `app_responsive.dart`, dan folder `widgets/`).
2. Pasang `AppTheme.lightTheme` pada `MaterialApp` / `MaterialApp.router` di `main.dart` (jangan ubah konfigurasi `routerConfig`, `home`, `routes`, atau `providers` di `main.dart`).
3. Jalankan `flutter analyze`. Pastikan **0 errors**.

### Tahap 2: Refactor Navigasi Utama (Shell/Sidebar)
1. Perbarui komponen Sidebar/Drawer/Scaffold utama agar menggunakan gaya Deep Navy (`#183558`) dan responsif (Desktop Sidebar, Tablet Rail, Mobile Drawer).
2. Pastikan seluruh item menu, kondisi *role/permission*, tombol *logout*, dan *route* tetap berfungsi persis seperti semula.
3. Jalankan `flutter analyze`. Pastikan **0 errors**.

### Tahap 3: Refactor Halaman Satu per Satu (Incremental Loop)
Lakukan perombakan halaman **satu file dalam satu waktu** dengan prosedur ketat berikut:
1. **Baca & Catat Kontrak Halaman:** Sebelum mengedit suatu halaman, daftar semua `controller`, variabel `state`, fungsi bisnis, dan `Navigator` yang ada di file tersebut.
2. **Ganti Lapisan Visual:** Ganti `Scaffold`/`Card`/`Button`/`TextField`/`Table` lama menggunakan `AppPageHeader`, `AppResponsiveGrid`, `AppCard`, `AppStatCard`, `AppButton`, `AppInput`, dan `AppAdaptiveDataView`.
3. **Cek Ulang Koneksi Logic:** Pastikan setiap `controller` dan fungsi yang dicatat pada langkah 1 sudah terpasang kembali di widget baru.
4. **Verifikasi Wajib (`flutter analyze`):** Jalankan `flutter analyze` pada file yang baru diubah.
   * Jika ada *error* atau *warning* (misal: *unused import* atau tipe parameter kurang tepat), perbaiki saat itu juga sebelum menyentuh file halaman berikutnya!

### Tahap 4: Pengecekan Akhir
* Jalankan `flutter analyze` secara menyeluruh pada proyek.
* Tampilkan ringkasan halaman apa saja yang sudah di-refactor dan cara *rollback* ke backup jika pengguna ingin membandingkan hasilnya.