import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Custom-scheme deep linking.
///
/// Links use the shape `sonde://app/<router-path>` so that the URI path
/// maps 1:1 onto go_router locations, e.g.
/// `sonde://app/podcast/episode/detail/42` -> `/podcast/episode/detail/42`.
/// Auth-gating is left to the router redirect; unknown paths simply fall
/// through to go_router's error page.
class DeepLinks {
  DeepLinks._();

  static const String scheme = 'sonde';

  /// Deep link that opens the episode detail page for [episodeId].
  static String episodeDeepLink(int episodeId) =>
      '$scheme://app/podcast/episode/detail/$episodeId';

  /// Maps an incoming link URI to a router location, or null when the
  /// URI is not a sonde deep link with a usable path.
  static String? routerLocationFromUri(Uri uri) {
    if (uri.scheme != scheme) return null;
    final path = uri.path;
    if (path.isEmpty || path == '/') return null;
    return uri.hasQuery ? '$path?${uri.query}' : path;
  }
}

/// Emits deep link URIs while the app is running. Override in tests
/// with a fake stream.
final deepLinkStreamProvider = Provider<Stream<Uri>>((ref) {
  return AppLinks().uriLinkStream;
});

/// Resolves the link (if any) that launched the app. Override in tests
/// with a pre-resolved Future.
final initialDeepLinkProvider = Provider<Future<Uri?>>((ref) {
  return AppLinks().getInitialLink();
});
