import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/auth_storage.dart';
import 'core/navigator_key.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize intl locale data sebelum DateFormat/NumberFormat dipakai.
  // Tanpa ini, `intl` throw LocaleDataException di release mode.
  await initializeDateFormatting('id_ID', null);

  final storage = AuthStorage();
  final tokens = await storage.getTokens();

  runApp(AdminApp(initialTokens: tokens));
}

class AdminApp extends StatelessWidget {
  final Map<String, String?>? initialTokens;

  const AdminApp({super.key, this.initialTokens});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      home: initialTokens?['access_token'] != null
          ? DashboardScreen(
              accessToken: initialTokens!['access_token']!,
              refreshToken: initialTokens!['refresh_token'] ?? '',
              username: initialTokens!['username'] ?? 'admin',
              nama: initialTokens!['nama'] ?? '',
              role: initialTokens!['role'] ?? 'ADMIN',
            )
          : const LoginScreen(),
    );
  }
}
