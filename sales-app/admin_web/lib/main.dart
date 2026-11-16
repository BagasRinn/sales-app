import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/auth_storage.dart';
import 'core/navigator_key.dart';
import 'core/session_navigation.dart';
import 'presentation/screens/login_screen.dart';
// Dashboard + semua tab-nya dipisah ke chunk sendiri (deferred): layar login
// tidak perlu mengunduh ±2,9 MB kode yang belum tentu dipakai. Chunk ini baru
// diambil setelah user berhasil login (atau saat sesi tersimpan ditemukan).
import 'presentation/screens/dashboard_screen.dart' deferred as dashboard_ui;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dashboard tidak meng-import login_screen (supaya deferred import tidak
  // membentuk siklus), jadi pembuat layar login didaftarkan dari sini.
  registerLoginScreen(() => const LoginScreen());
  // Jangan await apa pun sebelum runApp: frame pertama (boot screen) harus
  // tampil secepat mungkin. Baca storage & data locale dilakukan di dalam
  // AdminApp supaya tidak menahan first paint.
  runApp(const AdminApp());
}

/// Hasil inisialisasi awal: token sesi (kalau ada) setelah storage dibaca.
class _InitialState {
  final Map<String, String?>? tokens;

  const _InitialState(this.tokens);
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final Future<_InitialState> _initial = _initialize();

  /// Menyiapkan data yang dibutuhkan layar pertama. Dijalankan setelah frame
  /// boot tampil, bukan sebelum runApp.
  static Future<_InitialState> _initialize() async {
    Map<String, String?>? tokens;

    await Future.wait<void>([
      // Locale data intl wajib siap sebelum DateFormat/NumberFormat dipakai.
      // Tanpa ini, `intl` throw LocaleDataException di release mode.
      initializeDateFormatting('id_ID', null).catchError((Object _) {}),
      Future<void>(() async {
        try {
          tokens = await AuthStorage().getTokens();
        } catch (_) {
          // Storage diblokir/rusak: anggap belum login, jangan gagalkan boot.
          tokens = null;
        }
      }),
    ]);

    return _InitialState(tokens);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      home: FutureBuilder<_InitialState>(
        future: _initial,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state == null) return const _BootScreen();
          if (state.tokens?['access_token'] == null) return const LoginScreen();

          return _DashboardLoader(
            builder: () => dashboard_ui.DashboardScreen(
              accessToken: state.tokens!['access_token']!,
              refreshToken: state.tokens!['refresh_token'] ?? '',
              username: state.tokens!['username'] ?? 'admin',
              nama: state.tokens!['nama'] ?? '',
              role: state.tokens!['role'] ?? 'ADMIN',
            ),
          );
        },
      ),
    );
  }
}

/// Mengunduh chunk dashboard lalu menampilkan layarnya.
///
/// Kegagalan unduhan (offline, cache rusak) tidak boleh membuat app berhenti
/// di boot screen tanpa jalan keluar — karena itu ada tombol "Coba lagi"
/// alih-alih layar kosong.
class _DashboardLoader extends StatefulWidget {
  final Widget Function() builder;

  const _DashboardLoader({required this.builder});

  @override
  State<_DashboardLoader> createState() => _DashboardLoaderState();
}

class _DashboardLoaderState extends State<_DashboardLoader> {
  late Future<void> _chunk = dashboard_ui.loadLibrary();

  void _retry() {
    setState(() => _chunk = dashboard_ui.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _chunk,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootScreen();
        }
        if (snapshot.hasError) {
          return _BootError(onRetry: _retry);
        }
        return widget.builder();
      },
    );
  }
}

/// Pengganti splash HTML selama inisialisasi awal berjalan.
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF183558),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    'SO',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Sales Order Admin',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: Color(0xFF183558),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Memuat panel…',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ditampilkan kalau chunk dashboard gagal diunduh.
class _BootError extends StatelessWidget {
  final VoidCallback onRetry;

  const _BootError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gagal memuat panel.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF183558),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Periksa koneksi internet lalu coba lagi.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
