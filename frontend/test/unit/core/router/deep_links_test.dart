import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/router/deep_links.dart';

void main() {
  group('DeepLinks.episodeDeepLink', () {
    test('builds a sonde link onto the episode detail route', () {
      expect(
        DeepLinks.episodeDeepLink(42),
        'sonde://app/podcast/episode/detail/42',
      );
    });
  });

  group('DeepLinks.routerLocationFromUri', () {
    test('maps a sonde link path onto the router location', () {
      expect(
        DeepLinks.routerLocationFromUri(
          Uri.parse('sonde://app/podcast/episode/detail/42'),
        ),
        '/podcast/episode/detail/42',
      );
    });

    test('preserves query parameters', () {
      expect(
        DeepLinks.routerLocationFromUri(
          Uri.parse('sonde://app/podcast/episodes/3?status=unplayed'),
        ),
        '/podcast/episodes/3?status=unplayed',
      );
    });

    test('ignores other schemes', () {
      expect(
        DeepLinks.routerLocationFromUri(
          Uri.parse('https://example.com/podcast/episode/detail/42'),
        ),
        isNull,
      );
    });

    test('ignores links without a usable path', () {
      expect(
        DeepLinks.routerLocationFromUri(Uri.parse('sonde://app')),
        isNull,
      );
      expect(
        DeepLinks.routerLocationFromUri(Uri.parse('sonde://app/')),
        isNull,
      );
    });
  });
}
