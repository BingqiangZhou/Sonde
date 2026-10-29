import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;
import 'package:sonde/core/widgets/adaptive_sheet_helper.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart' show PodcastSearchResult;
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover_episode_detail_sheet.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover_show_episodes_sheet.dart';

/// Static helper methods for discover-page interactions.
///
/// Extracted from PodcastListPage to reduce its size and isolate discover logic.
/// All methods are static to avoid mixin/State generic compatibility issues.
class DiscoverInteractionHandler {
  DiscoverInteractionHandler._();

  // --- Subscribe ---

  static Future<void> subscribeFromSearch(
    WidgetRef ref,
    BuildContext context,
    PodcastSearchResult result,
  ) async {
    final l10n = context.l10n;
    final feedUrl = result.feedUrl;
    final collectionName = result.collectionName;
    if (feedUrl == null || collectionName == null) {
      showErrorNotice(context, l10n.podcast_subscribe_failed('Invalid podcast data'));
      return;
    }

    try {
      await ref.read(podcastSubscriptionProvider.notifier).addSubscription(feedUrl: feedUrl);
      if (!context.mounted) return;
      showSuccessNotice(context, l10n.podcast_subscribe_success(collectionName));
    } catch (error) {
      if (!context.mounted) return;
      showErrorNotice(context, l10n.podcast_subscribe_failed(error.toString()));
    }
  }

  // --- Episode tap ---

  static Future<void> handleEpisodeTap(
    WidgetRef ref,
    BuildContext context,
    ITunesPodcastEpisodeResult episode,
  ) async {
    final resolved = await resolveEpisodeForSearchResult(ref, episode);
    if (!context.mounted || resolved == null) {
      if (context.mounted) showErrorNotice(context, context.l10n.podcast_failed_load_episodes);
      return;
    }
    await showEpisodeDetailSheetFromSearch(ref, context, resolved);
  }

  static Future<void> handleChartRowTap(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    if (item.isPodcastShow) {
      await showPodcastEpisodeInfoSheet(ref, context, item);
    } else {
      await showEpisodeDetailSheetFromChart(ref, context, item);
    }
  }

  // --- Sheets ---

  static Future<void> showPodcastEpisodeInfoSheet(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);
    final showId = item.itunesId ?? searchService.extractShowIdFromApplePodcastUrl(item.url);
    if (showId == null) {
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
      return;
    }

    try {
      final lookup = await searchService.lookupPodcastEpisodes(
        showId: showId,
        country: country,
      );
      if (!context.mounted || lookup.episodes.isEmpty) {
        if (context.mounted) showErrorNotice(context, l10n.podcast_no_episodes_found);
        return;
      }

      await showAdaptiveSheet<void>(
        context: context,
        builder: (sheetContext) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: DiscoverShowEpisodesSheet(
              showId: showId,
              showTitle: lookup.collectionName ?? item.title,
              episodes: lookup.episodes,
              onEpisodeSelected: (episode) {
                Navigator.of(sheetContext).pop();
                showEpisodeDetailSheetFromSearch(ref, context, episode);
              },
            ),
          );
        },
      );
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to show podcast episodes: $e');
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
    }
  }

  static Future<void> showEpisodeDetailSheetFromChart(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final selection = await resolveDiscoverEpisodeSelection(ref, context, item);
    if (selection == null || !context.mounted) return;

    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: selection.episode,
          ),
        );
      },
    );
  }

  static Future<void> showEpisodeDetailSheetFromSearch(
    WidgetRef ref,
    BuildContext context,
    ITunesPodcastEpisodeResult episode,
  ) async {
    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: episode,
          ),
        );
      },
    );
  }

  // --- Resolution ---

  static Future<DiscoverEpisodeSelection?> resolveDiscoverEpisodeSelection(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);
    final showId = searchService.extractShowIdFromApplePodcastUrl(item.url);
    final episodeTrackId =
        searchService.extractEpisodeIdFromApplePodcastUrl(item.url) ?? item.itunesId;

    if (showId == null || episodeTrackId == null) {
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
      return null;
    }

    try {
      final episode = await searchService.findEpisodeInLookup(
        showId: showId,
        episodeTrackId: episodeTrackId,
        country: country,
      );
      if (episode == null) {
        showErrorNotice(context, l10n.podcast_failed_load_episodes);
        return null;
      }
      return DiscoverEpisodeSelection(showId: showId, episode: episode);
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to resolve episode selection: $e');
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
      return null;
    }
  }

  static Future<ITunesPodcastEpisodeResult?> resolveEpisodeForSearchResult(
    WidgetRef ref,
    ITunesPodcastEpisodeResult episode,
  ) async {
    if (episode.resolvedAudioUrl?.isNotEmpty == true) return episode;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);
    try {
      return await searchService.findEpisodeInLookup(
        showId: episode.collectionId,
        episodeTrackId: episode.trackId,
        country: country,
      );
    } catch (e) {
      logger.AppLogger.debug('[Search] Failed to resolve episode: $e');
      return null;
    }
  }

  // --- Notice helpers ---

  static void showErrorNotice(BuildContext context, String message) {
    if (!context.mounted) return;
    showTopFloatingNotice(context, message: message, isError: true);
  }

  static void showSuccessNotice(BuildContext context, String message) {
    if (!context.mounted) return;
    showTopFloatingNotice(context, message: message);
  }
}

class DiscoverEpisodeSelection {
  const DiscoverEpisodeSelection({
    required this.showId,
    required this.episode,
  });

  final int showId;
  final ITunesPodcastEpisodeResult episode;
}
