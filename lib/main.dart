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
import 'state/appearance_provider.dart';
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
  final appearance = AppearanceProvider(store);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStore>.value(value: store),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<AssetRepository>.value(value: assetRepository),
        Provider<BorrowRepository>.value(value: borrowRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),
        Provider<ReportRepository>.value(value: reportRepository),
        ChangeNotifierProvider<AppearanceProvider>.value(value: appearance),
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
    final appearance = context.watch<AppearanceProvider>();

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appearance.mode,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: _router,
      builder: (context, child) {
        // The splash owns the screen until both its own timer and the session
        // restore are done, so the login page never flashes on a warm start.
        final showSplash = !_splashDone || auth.initialising;
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;

        return AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 460),
          reverseDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: child,
              ),
            );
          },
          child: showSplash
              ? SplashScreen(
                  key: const ValueKey('splash'),
                  onFinished: () {
                    if (mounted) setState(() => _splashDone = true);
                  },
                )
              : KeyedSubtree(
                  key: const ValueKey('app'),
                  child: child ?? const SizedBox.shrink(),
                ),
        );
      },
    );
  }
}
