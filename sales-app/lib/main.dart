import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'core/jwt_utils.dart';
import 'data/repositories/api_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/providers/draft_order_provider.dart';
import 'presentation/providers/home_stats_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Locale data harus diinisialisasi sebelum NumberFormat/DateFormat dengan locale kustom.
  await initializeDateFormatting('id_ID', null);
  runApp(const SalesApp());
}

class SalesApp extends StatefulWidget {
  const SalesApp({super.key});

  @override
  State<SalesApp> createState() => _SalesAppState();
}

class _SalesAppState extends State<SalesApp> {
  late final ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository(_apiService);
    final productRepository = ProductRepository(_apiService);
    final orderRepository = OrderRepository(_apiService);
    final customerRepository = CustomerRepository(_apiService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => DraftOrderProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeStatsProvider(orderRepository),
        ),
        Provider<CustomerRepository>.value(
          value: customerRepository,
        ),
      ],
      child: MaterialApp(
        title: 'Sales Order App',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: AuthWrapper(apiService: _apiService),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final ApiService apiService;

  const AuthWrapper({super.key, required this.apiService});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with WidgetsBindingObserver {
  bool _checking = true;
  AuthState? _lastAuthState;

  /// Auto-logout kalau app di-background lebih dari ini. Default 60 detik —
  /// cukup pendek untuk menutup skenario HP di-access orang/anak, cukup
  /// panjang supaya notifikasi/dial sebentar tidak memaksa re-login.
  static const Duration _backgroundTimeout = Duration(seconds: 60);

  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository(widget.apiService);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused) {
      _markBackgrounded();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      _checkBackgroundTimeout();
    }
  }

  Future<void> _markBackgrounded() async {
    await _authRepo.writeBackgroundPausedAt(DateTime.now());
  }

  Future<void> _checkBackgroundTimeout() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    // Skip kalau sudah logout — tidak perlu auto-logout lagi.
    if (authProvider.state != AuthState.authenticated) return;

    final lastPaused = await _authRepo.readBackgroundPausedAt();
    if (lastPaused == null) return;

    final elapsed = DateTime.now().difference(lastPaused);
    if (elapsed > _backgroundTimeout) {
      // Hapus timestamp supaya tidak re-trigger di cold start berikutnya.
      await _authRepo.writeBackgroundPausedAt(null);
      if (!mounted) return;
      authProvider.forceLogout(
        'Sesi berakhir karena aplikasi terlalu lama di latar belakang.',
      );
    }
  }

  Future<void> _checkAuth() async {
    widget.apiService.onTokenExpired = () {
      if (mounted) {
        context.read<AuthProvider>().forceLogout('Sesi login berakhir. Silakan masuk kembali.');
      }
    };

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkLoginStatus();

    if (authProvider.state == AuthState.authenticated) {
      final token = await authProvider.getToken();
      if (JwtUtils.isExpired(token)) {
        authProvider.forceLogout('Sesi login berakhir. Silakan masuk kembali.');
      }
    }

    if (mounted) {
      setState(() => _checking = false);
    }

    // Cold-start: kalau user terakhir kali pause lama dan app-nya di-kill,
    // timestamp di storage masih ada — enforce di sini.
    await _checkBackgroundTimeout();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authState = context.watch<AuthProvider>().state;

    // Saat state berpindah ke unauthenticated (logout / forceLogout / token
    // expired), pop semua pushed route supaya LoginScreen — yang dirender
    // oleh build() ini — benar-benar terlihat. Tanpa ini, route yang sedang
    // terbuka (mis. HomeScreen yang dipush manual oleh LoginScreen lama,
    // atau OrderDetailScreen) akan tetap di top of stack dan user terjebak.
    if (authState == AuthState.unauthenticated &&
        _lastAuthState != AuthState.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      });
    }
    _lastAuthState = authState;

    if (authState == AuthState.authenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
