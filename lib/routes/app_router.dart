import 'package:go_router/go_router.dart';

import '../features/approvals/approvals_screen.dart';
import '../features/assets/asset_detail_screen.dart';
import '../features/assets/asset_form_screen.dart';
import '../features/assets/assets_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/requests/my_requests_screen.dart';
import '../features/requests/request_detail_screen.dart';
import '../features/requests/request_form_screen.dart';
import '../features/shell/app_shell.dart';
import '../state/auth_provider.dart';

/// Builds the router. `auth` is the change notifier that drives redirects, so
/// signing in or out moves the user between the auth screens and the app.
GoRouter buildRouter(AuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final signedIn = auth.isSignedIn;
      final location = state.matchedLocation;
      const publicRoutes = {'/login', '/register', '/forgot-password'};

      if (!signedIn) {
        return publicRoutes.contains(location) ? null : '/login';
      }
      if (publicRoutes.contains(location)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/assets',
              builder: (context, state) => const AssetsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const AssetFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => AssetDetailScreen(
                    assetId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => AssetFormScreen(
                        assetId: state.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/requests',
              builder: (context, state) => const MyRequestsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => RequestFormScreen(
                    assetId: state.uri.queryParameters['asset'],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => RequestDetailScreen(
                    requestId: state.pathParameters['id']!,
                    showRequester: true,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/approvals',
              builder: (context, state) => const ApprovalsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => RequestDetailScreen(
                    requestId: state.pathParameters['id']!,
                    showRequester: true,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'users',
                  builder: (context, state) => const UserManagementScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
  return router;
}