import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/api_service.dart';
import 'core/web_auth_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/bulletin_repository.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/providers/home_stats_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/draft_order_provider.dart';
import 'presentation/providers/customer_provider.dart';
import 'presentation/providers/bulletin_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Locale data harus diinisialisasi sebelum DateFormat dengan locale kustom
  // dipanggil — kalau tidak, DateFormat('dd MMM ...', 'id') melempar
  // LocaleDataException dan order tidak bisa di-render.
  await initializeDateFormatting('id', null);
  runApp(const SalesWebApp());
}

class SalesWebApp extends StatelessWidget {
  const SalesWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final authStorage = WebAuthStorage();
    final authRepo = AuthRepository(apiService, authStorage);
    final orderRepo = OrderRepository(apiService);
    final customerRepo = CustomerRepository(apiService);
    final productRepo = ProductRepository(apiService);
    final bulletinRepo = BulletinRepository(apiService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepo: authRepo, api: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeStatsProvider(orderRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomerProvider(customerRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => DraftOrderProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => BulletinProvider(bulletinRepo),
        ),
        Provider.value(value: apiService),
      ],
      child: MaterialApp(
        title: 'Sales App',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AuthWrapper(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFEFF6FF),
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF2563EB), size: 24);
          }
          return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkLoginStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.state == AuthState.initial || auth.state == AuthState.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (auth.state == AuthState.authenticated) {
          return const AppShell();
        }
        return const LoginScreen();
      },
    );
  }
}
