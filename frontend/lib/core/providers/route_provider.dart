import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for tracking the current route location
/// Updated by navigation observers or route changes
final currentRouteProvider = NotifierProvider<CurrentRouteNotifier, String>(CurrentRouteNotifier.new);

class CurrentRouteNotifier extends Notifier<String> {
  @override
  String build() {
    return '/';
  }

  void setRoute(String route) {
    state = route;
  }
}

/// Provider that checks if the current route is a podcast episode detail page
/// where the expanded player overlay should be suppressed
final isOnEpisodeDetailPageProvider = Provider<bool>((ref) {
  final route = ref.watch(currentRouteProvider);
  return route.contains('/podcast/episode/detail/');
});
