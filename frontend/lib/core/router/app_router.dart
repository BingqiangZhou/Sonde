import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/platform/adaptive_page_route.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/auth/presentation/pages/auth_verify_page.dart';
import 'package:sonde/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:sonde/features/auth/presentation/pages/login_page.dart';
import 'package:sonde/features/auth/presentation/pages/onboarding_page.dart';
import 'package:sonde/features/auth/presentation/pages/register_page.dart';
import 'package:sonde/features/auth/presentation/pages/reset_password_page.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/auth/presentation/providers/onboarding_provider.dart';
import 'package:sonde/features/home/presentation/pages/home_page.dart';
import 'package:sonde/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:sonde/features/podcast/presentation/pages/site_all_episodes_page.dart';
import 'package:sonde/features/podcast/presentation/pages/site_archive_page.dart';
import 'package:sonde/features/podcast/presentation/pages/site_favorites_page.dart';
import 'package:sonde/features/podcast/presentation/pages/site_reading_page.dart';
import 'package:sonde/features/podcast/presentation/pages/site_report_issue_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_episodes_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_highlights_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:sonde/features/profile/presentation/pages/profile_cache_management_page.dart';
import 'package:sonde/features/profile/presentation/pages/profile_page.dart';
import 'package:sonde/features/profile/presentation/pages/profile_subscriptions_page.dart';
import 'package:sonde/features/settings/presentation/pages/appearance_page.dart';
import 'package:sonde/features/splash/presentation/pages/splash_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

Page<T> _buildPageWithTransition<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return adaptivePageTransition<T>(
    child: child,
    pageKey: ValueKey<String>(state.pageKey.value),
  );
}

Page<T> _buildModalPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return adaptivePageTransition<T>(
    child: child,
    pageKey: ValueKey<String>(state.pageKey.value),
    fullscreenDialog: true,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    observers: [appRouteObserver],
    refreshListenable: AuthStateListenable(ref),
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const SplashPage(),
        ),
      ),

      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: '/auth-verify',
        name: 'auth-verify',
        redirect: (context, state) {
          if (kDebugMode) return null; // allow in debug builds
          return '/login'; // redirect to login in release builds
        },
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const AuthVerifyPage(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return _buildPageWithTransition(
            state: state,
            child: ResetPasswordPage(token: token),
          );
        },
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const OnboardingPage(),
        ),
      ),

      // Main app shell with persistent tab navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellWidget(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Discover (Podcast list)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                name: 'discover',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const PodcastListPage(),
                ),
              ),
            ],
          ),
          // Branch 1: Feed (default)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                name: 'feed',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const PodcastFeedPage(),
                ),
              ),
            ],
          ),
          // Branch 2: Reading (three-kind reports, Phase G)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reading',
                name: 'reading',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const SiteReadingPage(),
                ),
              ),
            ],
          ),
          // Branch 3: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => _buildPageWithTransition(
                  state: state,
                  child: const ProfilePage(),
                ),
                routes: [
                  // Profile sub-routes push over the shell
                  GoRoute(
                    path: 'cache',
                    name: 'profile-cache',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const ProfileCacheManagementPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'favorites',
                    name: 'profile-favorites',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const SiteFavoritesPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'subscriptions',
                    name: 'profile-subscriptions',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const ProfileSubscriptionsPage(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Pushed routes (cover the shell, no bottom nav)

      GoRoute(
        path: '/settings/appearance',
        name: 'appearance',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const AppearancePage(),
        ),
      ),

      // Legacy reports deep link → reading tab (Phase G)
      GoRoute(
        path: '/reports',
        redirect: (context, state) => '/reading',
      ),

      // Reading sub-pages (pushed over the shell)
      GoRoute(
        path: '/reading/archive',
        name: 'reading-archive',
        pageBuilder: (context, state) => _buildModalPage(
          state: state,
          child: SiteArchivePage(
              initialKind: SiteReportIssuePage.parseKind(
                state.uri.queryParameters['kind'],
              ),
          ),
        ),
      ),
      GoRoute(
        path: '/reading/all',
        name: 'reading-all',
        pageBuilder: (context, state) => _buildModalPage(
          state: state,
          child: const SiteAllEpisodesPage(),
        ),
      ),
      GoRoute(
        path: '/reading/issue/:kind/:key',
        name: 'reading-issue',
        pageBuilder: (context, state) {
          final kind = SiteReportIssuePage.parseKind(
            state.pathParameters['kind'],
          );
          final key = state.pathParameters['key'] ?? '';
          if (kind == null || key.isEmpty) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_navigation_arguments)),
              ),
            );
          }
          return _buildModalPage(
            state: state,
            child: SiteReportIssuePage(kind: kind, reportKey: key),
          );
        },
      ),

      // Highlights
      GoRoute(
        path: '/highlights',
        name: 'highlights',
        pageBuilder: (context, state) {
          final dateParam = state.uri.queryParameters['date'];
          final parsedDate = _parseDateOnlyQuery(dateParam);
          return _buildModalPage(
            state: state,
            child: PodcastHighlightsPage(initialDate: parsedDate),
          );
        },
      ),

      // Podcast routes (cover the shell)
      GoRoute(
        path: '/podcast',
        name: 'podcast',
        redirect: (context, state) => '/discover',
      ),
      GoRoute(
        path: '/podcast/episodes/:subscriptionId',
        name: 'podcastEpisodes',
        pageBuilder: (context, state) {
          final args = PodcastEpisodesPageArgs.extractFromState(state);
          if (args == null) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_navigation_arguments)),
              ),
            );
          }
          return _buildPageWithTransition(
            state: state,
            child: PodcastEpisodesPage(
                subscriptionId: args.subscriptionId,
                podcastTitle: args.podcastTitle,
                subscription: args.subscription,
              ),
          );
        },
      ),
      GoRoute(
        path: '/podcast/episodes/:subscriptionId/:episodeId',
        name: 'episodeDetail',
        pageBuilder: (context, state) {
          final args = PodcastEpisodeDetailPageArgs.extractFromState(state);
          if (args == null) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_navigation_arguments)),
              ),
            );
          }
          return _buildPageWithTransition(
            state: state,
            child: PodcastEpisodeDetailPage(episodeId: args.episodeId),
          );
        },
      ),
      GoRoute(
        path: '/podcast/episode/detail/:episodeId',
        name: 'episodeDetailDirect',
        pageBuilder: (context, state) {
          final episodeId = int.tryParse(
            state.pathParameters['episodeId'] ?? '',
          );
          if (episodeId == null) {
            final l10n = context.l10n;
            return _buildPageWithTransition(
              state: state,
              child: Scaffold(
                body: Center(child: Text(l10n.invalid_episode_id)),
              ),
            );
          }
          return _buildPageWithTransition(
            state: state,
            child: PodcastEpisodeDetailPage(episodeId: episodeId),
          );
        },
      ),
    ],

    // Redirect logic
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isForgotPassword = state.matchedLocation.startsWith(
        '/forgot-password',
      );
      final isResetPassword = state.matchedLocation.startsWith(
        '/reset-password',
      );

      // Redirect legacy /home to /feed
      if (state.matchedLocation == '/home') {
        return '/feed';
      }

      // Allow Splash
      if (isSplash) return null;

      // Allow password reset pages
      if (isForgotPassword || isResetPassword) {
        return null;
      }

      if (!isAuthenticated) {
        if (isLoggingIn || isRegistering) {
          return null;
        }
        return '/login';
      } else {
        // Authenticated user checks
        if (isLoggingIn || isRegistering) {
          return '/feed';
        }

        // Onboarding check: if not completed, redirect to onboarding
        final hasCompletedOnboarding = ref.read(onboardingCompletedProvider);
        if (!hasCompletedOnboarding && !isOnboarding) {
          return '/onboarding';
        }
        // Don't let authenticated users go back to onboarding if completed
        if (hasCompletedOnboarding && isOnboarding) {
          return '/feed';
        }

        return null;
      }
    },

    // Error handling
    errorBuilder: (context, state) => ErrorPage(error: state.error),
  );
});

// Helper for refreshListenable - notifies on auth status or onboarding changes
class AuthStateListenable extends ChangeNotifier {

  AuthStateListenable(this.ref) {
    ref.listen(authProvider.select((s) => s.isAuthenticated), (previous, next) {
      notifyListeners();
    });
    ref.listen(onboardingCompletedProvider, (previous, next) {
      notifyListeners();
    });
  }
  final Ref ref;
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: AppEmptyState(
            icon: Icons.error_outline,
            title: l10n.unknown_error,
            subtitle: error?.toString() ?? l10n.unknown_error,
            action: FilledButton(
              onPressed: () => context.go('/feed'),
              child: Text(l10n.home),
            ),
          ),
    );
  }
}

DateTime? _parseDateOnlyQuery(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(local.year, local.month, local.day);
}

