import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/splash/presentation/pages/splash_page.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._isAuthenticated);

  final bool _isAuthenticated;

  @override
  AuthState build() {
    return AuthState(isAuthenticated: _isAuthenticated);
  }
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(body: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) =>
                    const Scaffold(body: Text('discover')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) =>
                    const Scaffold(body: Text('feed')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const Scaffold(body: Text('profile')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login')),
      ),
    ],
  );
}

Widget _app({required bool authenticated}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _TestAuthNotifier(authenticated)),
    ],
    child: MaterialApp.router(routerConfig: _router()),
  );
}

void main() {
  testWidgets('SplashPage shows loader and redirects to login', (tester) async {
    await tester.pumpWidget(_app(authenticated: false));
    // 首帧即加载态：导航在 postFrameCallback 中执行，额外 pump 会跳转走
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('SplashPage shows loader and redirects to home', (tester) async {
    await tester.pumpWidget(_app(authenticated: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });
}
