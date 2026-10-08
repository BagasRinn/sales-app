import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/api_service.dart';
import 'core/web_auth_storage.dart';
import 'core/design_system.dart';
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
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
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
