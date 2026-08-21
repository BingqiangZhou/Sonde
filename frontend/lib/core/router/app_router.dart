import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/platform/adaptive_page_route.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/home/presentation/pages/home_page.dart';
import 'package:sonde/features/pairing/presentation/pages/pairing_page.dart';
import 'package:sonde/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_charts_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_daily_report_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_episodes_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import 'package:sonde/features/profile/presentation/pages/profile_cache_management_page.dart';
import 'package:sonde/features/profile/presentation/pages/profile_history_page.dart';
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
        path: '/pairing',
        name: 'pairing',
        pageBuilder: (context, state) => _buildPageWithTransition(
          state: state,
          child: const PairingPage(),
        ),
      ),
      // Dev-only API test harness; excluded from release builds.
      if (kDebugMode) ...[
      ],

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
                routes: [
                  // Full charts page pushed over the shell from a discover
                  // shelf's "see all"; ?section= picks which chart renders.
                  GoRoute(
                    path: 'charts',
                    name: 'discoverCharts',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) {
                      final section =
                          state.uri.queryParameters['section'] == 'episodes'
                              ? PodcastChartsSection.episodes
                              : PodcastChartsSection.shows;
                      return _buildModalPage(
                        state: state,
                        child: _PlayerAwareRouteFrame(
                          child: PodcastChartsPage(section: section),
                        ),
                      );
                    },
                  ),
                ],
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
          // Branch 2: Profile (previously Branch 3)
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
                      child: const _PlayerAwareRouteFrame(
                        child: ProfileCacheManagementPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'history',
                    name: 'profile-history',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const _PlayerAwareRouteFrame(
                        child: ProfileHistoryPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'subscriptions',
                    name: 'profile-subscriptions',
                    parentNavigatorKey: appNavigatorKey,
                    pageBuilder: (context, state) => _buildModalPage(
                      state: state,
                      child: const _PlayerAwareRouteFrame(
                        child: ProfileSubscriptionsPage(),
                      ),
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

      // Daily report
      GoRoute(
        path: '/reports/daily',
        name: 'dailyReport',
        pageBuilder: (context, state) {
          final dateParam = state.uri.queryParameters['date'];
          final parsedDate = _parseDateOnlyQuery(dateParam);
          return _buildModalPage(
            state: state,
            child: _PlayerAwareRouteFrame(
              child: PodcastDailyReportPage(
                initialDate: parsedDate,
              ),
            ),
          );
        },
      ),

      // Podcast routes (cover the shell)
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
            child: _PlayerAwareRouteFrame(
              child: PodcastEpisodesPage(
                subscriptionId: args.subscriptionId,
                podcastTitle: args.podcastTitle,
                subscription: args.subscription,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/podcast/episode/detail/:episodeId',
        name: 'episodeDetail',
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
            child: _PlayerAwareRouteFrame(
              child: PodcastEpisodeDetailPage(episodeId: episodeId),
            ),
          );
        },
      ),
    ],

    // Redirect logic
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isPairing = state.matchedLocation == '/pairing';
      final isSplash = state.matchedLocation == '/splash';

      // Redirect legacy /home to /feed
      if (state.matchedLocation == '/home') {
        return '/feed';
      }

      // Allow Splash
      if (isSplash) return null;

      if (!isAuthenticated) {
        if (isPairing) {
          return null;
        }
        return '/pairing';
      } else {
        // Authenticated user checks
        if (isPairing) {
          return '/feed';
        }

        return null;
      }
    },

    // Error handling
    errorBuilder: (context, state) => ErrorPage(error: state.error),
  );
});

// Helper for refreshListenable - notifies on auth status changes
class AuthStateListenable extends ChangeNotifier {

  AuthStateListenable(this.ref) {
    ref.listen(authProvider.select((s) => s.isAuthenticated), (previous, next) {
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

class _PlayerAwareRouteFrame extends StatelessWidget {
  const _PlayerAwareRouteFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PodcastPlayerLayoutFrame(child: child);
  }
}
