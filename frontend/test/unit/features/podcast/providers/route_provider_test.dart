import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/providers/route_provider.dart';

void main() {
  group('RouteProvider Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('currentRouteProvider', () {
      test('should have default route value of "/"', () {
        // Act
        final route = container.read(currentRouteProvider);

        // Assert
        expect(route, '/');
      });

      test('should update route when setRoute is called', () {
        // Arrange
        const newRoute = '/podcast/episodes/1/42';

        // Act
        container.read(currentRouteProvider.notifier).setRoute(newRoute);

        // Assert
        expect(container.read(currentRouteProvider), newRoute);
      });

      test('should handle multiple route updates', () {
        // Act & Assert - First update
        container.read(currentRouteProvider.notifier).setRoute('/feed');
        expect(container.read(currentRouteProvider), '/feed');

        // Act & Assert - Second update
        container.read(currentRouteProvider.notifier).setRoute('/discover');
        expect(container.read(currentRouteProvider), '/discover');

        // Act & Assert - Third update
        container.read(currentRouteProvider.notifier).setRoute('/profile');
        expect(container.read(currentRouteProvider), '/profile');
      });

      test('should handle routes with query parameters', () {
        // Arrange
        const routeWithQuery = '/feed?page=2&sort=newest';

        // Act
        container.read(currentRouteProvider.notifier).setRoute(routeWithQuery);

        // Assert
        expect(container.read(currentRouteProvider), routeWithQuery);
      });

      test('should handle deep link routes', () {
        // Arrange
        const deepLinkRoute = '/podcast/episodes/123/456?position=120';

        // Act
        container.read(currentRouteProvider.notifier).setRoute(deepLinkRoute);

        // Assert
        expect(container.read(currentRouteProvider), deepLinkRoute);
      });
    });

    group('RouteProvider integration tests', () {
      test('should maintain state consistency across navigation flow', () {
        // Simulate navigation flow
        final notifier = container.read(currentRouteProvider.notifier);

        // 1. Start at root
        notifier.setRoute('/');
        expect(container.read(currentRouteProvider), '/');

        // 2. Navigate to feed
        notifier.setRoute('/feed');
        expect(container.read(currentRouteProvider), '/feed');

        // 3. Navigate to episode detail
        notifier.setRoute('/podcast/episodes/10/20');
        expect(container.read(currentRouteProvider), '/podcast/episodes/10/20');

        // 4. Navigate to discover
        notifier.setRoute('/discover');
        expect(container.read(currentRouteProvider), '/discover');

        // 5. Navigate to direct episode detail
        notifier.setRoute('/podcast/episode/detail/20');
        expect(container.read(currentRouteProvider), '/podcast/episode/detail/20');
      });

      test('should handle rapid route changes', () {
        final notifier = container.read(currentRouteProvider.notifier);

        // Simulate rapid navigation
        for (var i = 0; i < 10; i++) {
          notifier.setRoute('/route/$i');
          expect(container.read(currentRouteProvider), '/route/$i');
        }

        // Final state should be the last route set
        expect(container.read(currentRouteProvider), '/route/9');
      });
    });
  });
}
