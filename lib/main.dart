import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/asset_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/borrow_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/supabase_service.dart';
import 'features/setup/setup_required_screen.dart';
import 'routes/app_router.dart';
import 'state/auth_provider.dart';
import 'state/inventory_provider.dart';
import 'state/notifications_provider.dart';
import 'state/requests_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    // No Supabase credentials were compiled in. Show the setup instructions in
    // a real MaterialApp rather than a bare widget: Scaffold needs
    // MaterialLocalizations, and a bare runApp would render it unstyled.
    runApp(
      MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const SetupRequiredScreen(),
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final client = SupabaseService.instance.client;
  final authRepository = AuthRepository(client);
  final assetRepository = AssetRepository(client);
  final borrowRepository = BorrowRepository(client);
  final notificationRepository = NotificationRepository(client);
  final reportRepository = ReportRepository(client);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<AssetRepository>.value(value: assetRepository),
        Provider<BorrowRepository>.value(value: borrowRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),
        Provider<ReportRepository>.value(value: reportRepository),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository)..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(assetRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => RequestsProvider(borrowRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationsProvider(notificationRepository),
        ),
      ],
      child: const BarangayBorrowApp(),
    ),
  );
}

class BarangayBorrowApp extends StatefulWidget {
  const BarangayBorrowApp({super.key});

  @override
  State<BarangayBorrowApp> createState() => _BarangayBorrowAppState();
}

class _BarangayBorrowAppState extends State<BarangayBorrowApp> {
  late final GoRouter _router = buildRouter(context.read<AuthProvider>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      builder: (context, child) {
        final auth = context.watch<AuthProvider>();
        // Hold the first frame until the session has been restored so the
        // user never sees the login screen flash on a warm start.
        if (auth.initialising) {
          return const SplashScreen();
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}