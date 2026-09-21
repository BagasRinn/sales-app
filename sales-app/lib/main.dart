import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/jwt_utils.dart';
import 'data/repositories/api_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/order_repository.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/cart_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';

void main() {
  runApp(const SalesApp());
}

class SalesApp extends StatefulWidget {
  const SalesApp({super.key});

  @override
  State<SalesApp> createState() => _SalesAppState();
}

class _SalesAppState extends State<SalesApp> {
  // Single shared ApiService instance for all repositories
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepository),
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

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    // Wire token expiry callback — triggers redirect to login
    widget.apiService.onTokenExpired = () {
      if (mounted) {
        context.read<AuthProvider>().forceLogout('Sesi login berakhir. Silakan masuk kembali.');
      }
    };

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkLoginStatus();

    // Also check if stored token is already expired before navigating
    if (authProvider.state == AuthState.authenticated) {
      final token = await authProvider.getToken();
      if (JwtUtils.isExpired(token)) {
        authProvider.forceLogout('Sesi login berakhir. Silakan masuk kembali.');
      }
    }

    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final authState = context.watch<AuthProvider>().state;

    if (authState == AuthState.authenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
