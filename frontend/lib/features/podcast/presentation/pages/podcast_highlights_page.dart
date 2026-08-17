import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_highlights_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/calendar_panel_dialog.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/highlight_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/panel_list_views.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

/// Page for displaying podcast highlights.
///
/// Shows a list of highlight cards with filtering by date and source.
/// Features a calendar popup for date selection and responsive layout.
class PodcastHighlightsPage extends ConsumerStatefulWidget {
  const PodcastHighlightsPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<PodcastHighlightsPage> createState() =>
      _PodcastHighlightsPageState();
}

class _PodcastHighlightsPageState extends ConsumerState<PodcastHighlightsPage> {
  final ScrollController _scrollController = ScrollController();
  late DateTime _focusedCalendarDay;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    final targetDate = _resolveInitialDate(widget.initialDate);
    _focusedCalendarDay = targetDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedHighlightDateProvider.notifier).setDate(targetDate);

      final isAuthenticated = ref.read(authProvider).isAuthenticated;
      if (!isAuthenticated) return;

      unawaited(_loadInitialHighlightsData(targetDate));
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    // Read pagination flags straight from the provider so no build-phase
    // syncing into local fields is needed.
    final hasMore = ref.read(highlightsProvider).value?.hasMore ?? false;
    if (!hasMore) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const delta = 200.0;

    if (maxScroll - currentScroll < delta) {
      _loadMoreHighlights();
    }
  }

  Future<void> _loadInitialHighlightsData(DateTime targetDate) async {
    try {
      await Future.wait([
        ref
            .read(highlightsProvider.notifier)
            .load(date: targetDate, forceRefresh: true),
        ref.read(highlightDatesProvider.notifier).load(forceRefresh: true),
      ]);

      if (!mounted) return;
      await ref
          .read(highlightDatesProvider.notifier)
          .ensureMonthCoverage(targetDate);
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.podcast_highlights_cannot_load,
          isError: true,
        );
      }
    }
  }

  Future<void> _loadMoreHighlights() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final selectedDate = ref.read(selectedHighlightDateProvider);
      await ref.read(highlightsProvider.notifier).loadNextPage(date: selectedDate);
    } catch (e) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.podcast_highlights_load_more_error,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PanelListPageScaffold(
      scaffoldKey: const Key('highlights_page'),
      appBarTitle: l10n.podcast_highlights_title,
      appBarActions: [_buildCalendarButton(context)],
      scrollController: _scrollController,
      topGap: context.spacing.xs,
      slivers: [..._buildHighlightsSlivers(context)],
    );
  }

  Widget _buildCalendarButton(BuildContext context) {
    final l10n = context.l10n;
    return HeaderCapsuleActionButton(
      key: const Key('highlights_calendar_menu_button'),
      tooltip: l10n.podcast_highlights_dates,
      onPressed: () {
        unawaited(_showCalendarPanel());
      },
      icon: Icons.calendar_month_outlined,
      circular: true,
    );
  }

  List<Widget> _buildHighlightsSlivers(BuildContext context) {
    final l10n = context.l10n;
    final highlightsAsync = ref.watch(highlightsProvider);
    final selectedDate = ref.watch(selectedHighlightDateProvider);
    final headerDate = selectedDate ?? _focusedCalendarDay;

    if (highlightsAsync.isLoading && highlightsAsync.value == null) {
      return panelStateSlivers(
        PanelStateView(
          title: EpisodeCardUtils.formatDate(headerDate),
          subtitle: l10n.podcast_highlights_loading,
          bare: true,
          bareBodyGap: true,
          body: LoadingStatusContent(
            key: const Key('highlights_loading_content'),
            title: l10n.podcast_highlights_loading_highlights,
            spinnerSize: 28,
            spinnerColor: Theme.of(context).colorScheme.primary,
            gapAfterSpinner: 12,
          ),
        ),
      );
    }

    if (highlightsAsync.hasError && highlightsAsync.value == null) {
      return panelStateSlivers(
        PanelStateView(
          title: EpisodeCardUtils.formatDate(headerDate),
          subtitle: l10n.podcast_highlights_load_failed,
          centerBody: false,
          body: panelErrorBody(
            context,
            icon: null,
            message: l10n.podcast_highlights_cannot_load,
            messageStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            retryLabel: l10n.podcast_highlights_retry,
            onRetry: () {
              final selectedDate = ref.read(selectedHighlightDateProvider);
              ref
                  .read(highlightsProvider.notifier)
                  .load(date: selectedDate, forceRefresh: true);
              ref
                  .read(highlightDatesProvider.notifier)
                  .load(forceRefresh: true);
            },
          ),
        ),
      );
    }

    final highlightsResponse = highlightsAsync.value;
    final highlights = highlightsResponse?.items ?? [];

    if (highlights.isEmpty) {
      return panelStateSlivers(
        PanelStateView(
          title: EpisodeCardUtils.formatDate(headerDate),
          subtitle: l10n.podcast_highlights_no_highs,
          centerBody: false,
          body: panelNoteBox(
            context,
            child: Text(
              l10n.podcast_highlights_empty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // Data state: panel header + divider + list items + bottom cap
    return panelDataSlivers(
      context,
      title: EpisodeCardUtils.formatDate(headerDate),
      subtitle: l10n.podcast_highlights_items(highlightsResponse?.total ?? 0),
      itemSlivers: [
        // Highlight items
        SliverList.builder(
          itemCount: highlights.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (itemContext, index) {
            if (index >= highlights.length) {
              return _buildLoadingMoreIndicator(itemContext);
            }
            final highlight = highlights[index];
            return _buildHighlightCard(itemContext, highlight);
          },
        ),
      ],
    );
  }

  Widget _buildHighlightCard(
    BuildContext context,
    HighlightResponse highlight,
  ) {
    return HighlightCard(
      key: Key('highlight_${highlight.id}'),
      highlight: highlight,
      onTap: () {
        context.push('/podcast/episode/detail/${highlight.episodeId}');
      },
      onFavoriteToggle: () {
        ref
            .read(highlightsProvider.notifier)
            .toggleFavorite(highlight.id);
      },
    );
  }

  Widget _buildLoadingMoreIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.colorScheme.primary,
              ),
            ),
            child: const CircularProgressIndicator.adaptive(
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCalendarPanel() async {
    final l10n = context.l10n;
    final datesAsync = ref.read(highlightDatesProvider);
    final selectedDate = ref.read(selectedHighlightDateProvider);
    final highlightDateKeys = <String>{
      for (final item in datesAsync.value?.dates ?? const <DateTime>[])
        EpisodeCardUtils.formatDate(item),
    };

    await showCalendarPanelDialog(
      context: context,
      titleText: l10n.podcast_highlights_dates,
      dateKeys: highlightDateKeys,
      selectedDate: selectedDate,
      focusedDay: _focusedCalendarDay,
      calendarKey: 'highlights_calendar',
      isLoadingDates: datesAsync.isLoading && datesAsync.value == null,
      loadingText: l10n.podcast_highlights_loading,
      onDaySelected: (pickedDay, focusedDay) {
        unawaited(
          _handleCalendarDaySelected(
            pickedDay: pickedDay,
            focusedDay: focusedDay,
          ),
        );
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedCalendarDay = focusedDay;
        });
        unawaited(
          ref
              .read(highlightDatesProvider.notifier)
              .ensureMonthCoverage(focusedDay),
        );
      },
    );
  }

  Future<void> _handleCalendarDaySelected({
    required DateTime pickedDay,
    required DateTime focusedDay,
  }) async {
    final normalizedSelected = _toDateOnly(pickedDay);
    final normalizedFocused = _toDateOnly(focusedDay);
    if (mounted) {
      setState(() {
        _focusedCalendarDay = normalizedFocused;
      });
    }
    ref
        .read(selectedHighlightDateProvider.notifier)
        .setDate(normalizedSelected);
    await ref
        .read(highlightsProvider.notifier)
        .load(date: normalizedSelected, forceRefresh: true);
  }

  DateTime _resolveInitialDate(DateTime? rawValue) {
    final now = _toDateOnly(DateTime.now());
    final minimum = DateTime(2000);
    final fallback = now.subtract(const Duration(days: 1));
    if (rawValue == null) return fallback;

    final normalized = _toDateOnly(rawValue);
    if (normalized.isAfter(now)) return now;
    if (normalized.isBefore(minimum)) return minimum;
    return normalized;
  }

  DateTime _toDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }
}
