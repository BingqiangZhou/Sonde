
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/router/app_router.dart';
import 'package:sonde/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

/// Navigation arguments for podcast episodes page
class PodcastEpisodesPageArgs {

  const PodcastEpisodesPageArgs({
    required this.subscriptionId,
    this.podcastTitle,
    this.subscription,
  });

  /// Creates args from a subscription object
  factory PodcastEpisodesPageArgs.fromSubscription(
    PodcastSubscriptionModel subscription,
  ) {
    return PodcastEpisodesPageArgs(
      subscriptionId: subscription.id,
      podcastTitle: subscription.title,
      subscription: subscription,
    );
  }
  final int subscriptionId;
  final String? podcastTitle;
  final PodcastSubscriptionModel? subscription;

  /// Extracts args from GoRouter state
  static PodcastEpisodesPageArgs? extractFromState(GoRouterState state) {
    final subscriptionIdStr = state.pathParameters['subscriptionId'];
    if (subscriptionIdStr == null) return null;

    final subscriptionId = int.tryParse(subscriptionIdStr);
    if (subscriptionId == null) return null;

    final subscription = state.extra as PodcastSubscriptionModel?;

    return PodcastEpisodesPageArgs(
      subscriptionId: subscriptionId,
      podcastTitle: state.uri.queryParameters['title'] ?? subscription?.title,
      subscription: subscription,
    );
  }
}

/// Helper class for podcast navigation
class PodcastNavigation {
  const PodcastNavigation._();

  static BuildContext? _resolveRoutingContext(BuildContext context) {
    // Use maybeOf instead of try-catch for cleaner control flow
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      return context;
    }
    return appNavigatorKey.currentContext;
  }

  /// Navigate to episodes page
  static void goToEpisodes(
    BuildContext context, {
    required int subscriptionId,
    String? podcastTitle,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    final query = podcastTitle != null
        ? {'title': podcastTitle}
        : <String, dynamic>{};
    GoRouter.of(routingContext).pushNamed(
      'podcastEpisodes',
      pathParameters: {'subscriptionId': subscriptionId.toString()},
      queryParameters: query,
    );
  }

  /// Navigate to episodes page from subscription object
  static void goToEpisodesFromSubscription(
    BuildContext context,
    PodcastSubscriptionModel subscription,
  ) {
    goToEpisodes(
      context,
      subscriptionId: subscription.id,
      podcastTitle: subscription.title,
    );
  }

  /// Navigate to episode detail page
  static void goToEpisodeDetail(
    BuildContext context, {
    required int episodeId,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    GoRouter.of(routingContext).pushNamed(
      'episodeDetail',
      pathParameters: {'episodeId': episodeId.toString()},
    );
  }

  /// Navigate to daily report page
  static void goToDailyReport(
    BuildContext context, {
    DateTime? date,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    GoRouter.of(routingContext).pushNamed(
      'dailyReport',
      queryParameters: {
        if (date != null) 'date': EpisodeCardUtils.formatDate(date),
      },
    );
  }

  /// Navigate to highlights page
  static void goToHighlights(
    BuildContext context, {
    DateTime? date,
  }) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext == null) {
      return;
    }
    GoRouter.of(routingContext).pushNamed(
      'highlights',
      queryParameters: {
        if (date != null) 'date': EpisodeCardUtils.formatDate(date),
      },
    );
  }

  /// Navigate to podcast list page deterministically
  static void popToList(BuildContext context) {
    final routingContext = _resolveRoutingContext(context);
    if (routingContext != null) {
      GoRouter.of(routingContext).go('/discover');
    }
  }
}
