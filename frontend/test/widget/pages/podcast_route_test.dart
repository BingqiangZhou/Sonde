import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

// Mirrors the podcast routes in app_router.dart: the episodes list at
// /podcast/episodes/:subscriptionId and the single episode detail route at
// /podcast/episode/detail/:episodeId.
void main() {
  group('Podcast Route Tests', () {
    testWidgets('should navigate to episodes list and episode detail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/discover',
              routes: [
                GoRoute(
                  path: '/discover',
                  builder: (context, state) => const Scaffold(body: Text('Podcast List')),
                ),
                GoRoute(
                  path: '/podcast/episodes/:subscriptionId',
                  name: 'podcastEpisodes',
                  builder: (context, state) => Scaffold(
                    body: Text('Episodes for ${state.pathParameters['subscriptionId']}'),
                  ),
                ),
                GoRoute(
                  path: '/podcast/episode/detail/:episodeId',
                  name: 'episodeDetail',
                  builder: (context, state) => Scaffold(
                    body: Text('Episode ${state.pathParameters['episodeId']}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Podcast List'), findsOneWidget);

      final context = tester.element(find.text('Podcast List'));
      final router = GoRouter.of(context);

      // Episodes list: /podcast/episodes/1
      router.go('/podcast/episodes/1');
      await tester.pumpAndSettle();

      expect(find.text('Episodes for 1'), findsOneWidget);

      // Episode detail: /podcast/episode/detail/2
      router.go('/podcast/episode/detail/2');
      await tester.pumpAndSettle();

      expect(find.text('Episode 2'), findsOneWidget);
    });

    testWidgets('should reject legacy nested detail route and wrong plural form', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/discover',
              routes: [
                GoRoute(
                  path: '/discover',
                  builder: (context, state) => const Scaffold(body: Text('Podcast List')),
                ),
                GoRoute(
                  path: '/podcast/episodes/:subscriptionId',
                  name: 'podcastEpisodes',
                  builder: (context, state) => Scaffold(
                    body: Text('Episodes for ${state.pathParameters['subscriptionId']}'),
                  ),
                ),
                GoRoute(
                  path: '/podcast/episode/detail/:episodeId',
                  name: 'episodeDetail',
                  builder: (context, state) => Scaffold(
                    body: Text('Episode ${state.pathParameters['episodeId']}'),
                  ),
                ),
              ],
              errorBuilder: (context, state) => Scaffold(
                body: Text('Route Error: ${state.error}'),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.text('Podcast List'));
      final router = GoRouter.of(context);

      // Legacy two-segment detail path was removed in favor of
      // /podcast/episode/detail/:episodeId.
      router.go('/podcast/episodes/1/2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Route Error'), findsOneWidget);

      // Wrong plural form is still rejected.
      router.go('/podcasts/episodes/1');
      await tester.pumpAndSettle();
      expect(find.textContaining('Route Error'), findsOneWidget);
    });
  });
}
