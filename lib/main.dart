import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/local/local_store.dart';
import 'data/repositories/asset_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/borrow_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/report_repository.dart';
import 'features/splash/splash_screen.dart';
import 'routes/app_router.dart';
import 'state/auth_provider.dart';
import 'state/inventory_provider.dart';
import 'state/notifications_provider.dart';
import 'state/requests_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The only startup work: open (or create) the on-device database. No
  // network, no credentials, no setup screen.
  final store = await LocalStore.open();

  final authRepository = AuthRepository(store);
  final assetRepository = AssetRepository(store);
  final borrowRepository = BorrowRepository(store);
  final notificationRepository = NotificationRepository(store);
  final reportRepository = ReportRepository(store);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStore>.value(value: store),
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
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      builder: (context, child) {
        // The splash owns the screen until both its own timer and the session
        // restore are done, so the login page never flashes on a warm start.
        if (!_splashDone || auth.initialising) {
          return SplashScreen(
            onFinished: () {
              if (mounted) setState(() => _splashDone = true);
            },
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
