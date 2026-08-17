import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_dialog_helper.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/core/utils/episode_description_helper.dart';
import 'package:sonde/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:sonde/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/add_podcast_dialog.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/panel_list_views.dart';
import 'package:sonde/shared/widgets/loading_widget.dart';

class ProfileSubscriptionsPage extends ConsumerStatefulWidget {
  const ProfileSubscriptionsPage({super.key});

  @override
  ConsumerState<ProfileSubscriptionsPage> createState() =>
      _ProfileSubscriptionsPageState();
}

class _ProfileSubscriptionsPageState
    extends ConsumerState<ProfileSubscriptionsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(podcastSubscriptionProvider.notifier)
          .loadSubscriptions();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }

    final state = ref.read(podcastSubscriptionProvider);
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }

    ref.read(podcastSubscriptionProvider.notifier).loadMoreSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(
      podcastSubscriptionProvider.select(
        (value) => (
          subscriptions: value.subscriptions,
          hasMore: value.hasMore,
          isLoading: value.isLoading,
          isLoadingMore: value.isLoadingMore,
          total: value.total,
          error: value.error,
        ),
      ),
    );

    return PanelListPageScaffold(
      appBarTitle: l10n.profile_subscriptions,
      appBarActions: [
        HeaderCapsuleActionButton(
          key: const Key('profile_subscriptions_action_add'),
          tooltip: l10n.podcast_add_podcast,
          onPressed: () {
            showAppDialog<void>(
              context: context,
              builder: (context) => const AddPodcastDialog(),
            );
          },
          icon: Icons.add,
          circular: true,
        ),
      ],
      scrollController: _scrollController,
      showScrollbar: false,
      onRefresh: () => ref
          .read(podcastSubscriptionProvider.notifier)
          .refreshSubscriptions(),
      slivers: [
        ..._buildStateSlivers(
          context,
          l10n,
          subscriptions: state.subscriptions,
          hasMore: state.hasMore,
          isLoading: state.isLoading,
          isLoadingMore: state.isLoadingMore,
          total: state.total,
          error: state.error,
        ),
      ],
    );
  }

  List<Widget> _buildStateSlivers(
    BuildContext context,
    AppLocalizations l10n, {
    required List<PodcastSubscriptionModel> subscriptions,
    required bool hasMore,
    required bool isLoading,
    required bool isLoadingMore,
    required int total,
    required String? error,
  }) {
    if (isLoading && subscriptions.isEmpty) {
      return _buildLoadingSlivers(context, l10n);
    }

    if (error != null && subscriptions.isEmpty) {
      return _buildErrorSlivers(context, l10n, error);
    }

    if (subscriptions.isEmpty) {
      return _buildEmptySlivers(context, l10n);
    }

    return _buildDataSlivers(
      context,
      l10n,
      subscriptions: subscriptions,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      total: total,
    );
  }

  List<Widget> _buildDataSlivers(
    BuildContext context,
    AppLocalizations l10n, {
    required List<PodcastSubscriptionModel> subscriptions,
    required bool hasMore,
    required bool isLoadingMore,
    required int total,
  }) {
    return panelDataSlivers(
      context,
      title: l10n.profile_subscriptions,
      subtitle: l10n.profile_subscriptions_count(total),
      hideTitle: true,
      headerPadding: _panelHeaderPadding(context),
      itemSlivers: [
        // List items
        SliverList.builder(
          itemCount: subscriptions.length + 1,
          itemBuilder: (context, index) {
            if (index == subscriptions.length) {
              return _buildLoadingIndicator(
                context,
                hasMore,
                isLoadingMore,
                total,
                l10n,
              );
            }

            final subscription = subscriptions[index];
            return _buildSubscriptionCard(context, subscription, l10n);
          },
        ),
      ],
    );
  }

  List<Widget> _buildLoadingSlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.profile_subscriptions,
        subtitle: l10n.profile_subscriptions_subtitle,
        headerPadding: _panelHeaderPadding(context),
        bare: true,
        body: LoadingStatusContent(
          key: const Key('profile_subscriptions_loading_content'),
          title: l10n.loading,
          spinnerSize: 28,
          gapAfterSpinner: 12,
        ),
      ),
    );
  }

  List<Widget> _buildErrorSlivers(
    BuildContext context,
    AppLocalizations l10n,
    String error,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.profile_subscriptions,
        subtitle: l10n.profile_subscriptions_subtitle,
        headerPadding: _panelHeaderPadding(context),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: panelErrorBody(context, message: error),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmptySlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.profile_subscriptions,
        subtitle: l10n.profile_subscriptions_subtitle,
        headerPadding: _panelHeaderPadding(context),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: panelEmptyBody(
              context,
              icon: Icons.subscriptions_outlined,
              title: l10n.podcast_no_subscriptions,
              subtitle: l10n.feed_no_subscriptions_hint,
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsetsGeometry _panelHeaderPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      context.spacing.mdLg,
      context.spacing.mdLg,
      context.spacing.mdLg,
      context.spacing.smMd,
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    PodcastSubscriptionModel subscription,
    AppLocalizations l10n,
  ) {
    return RepaintBoundary(
      key: ValueKey('subscription_card_${subscription.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Material(
          color: Colors.transparent,
          child: AdaptiveInkWell(
            onTap: () {
              context.push(
                '/podcast/episodes/${subscription.id}',
                extra: subscription,
              );
            },
            borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
            child: SizedBox(
            key: ValueKey('profile_subscription_card_content_${subscription.id}'),
            height: kPodcastRowCardTargetHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kPodcastRowCardHorizontalPadding,
                vertical: context.spacing.xsSm,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      appThemeOf(context).itemRadius,
                    ),
                    child: PodcastImageWidget(
                      imageUrl: subscription.imageUrl,
                      width: kPodcastRowCardImageSize,
                      height: kPodcastRowCardImageSize,
                      iconSize: 24,
                      iconColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: kPodcastRowCardHorizontalGap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.spacing.xs),
                        Text(
                          subscription.description != null
                              ? EpisodeDescriptionHelper.stripHtmlTags(
                                  subscription.description,
                                )
                              : l10n.podcast_description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLoadingIndicator(
    BuildContext context,
    bool hasMore,
    bool isLoadingMore,
    int total,
    AppLocalizations l10n,
  ) {
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Center(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Theme(
                data: theme.copyWith(
                  colorScheme: theme.colorScheme.copyWith(
                    primary: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                child: const CircularProgressIndicator.adaptive(),
              );
            },
          ),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Center(
          child: Text(
            l10n.profile_subscriptions_all_loaded(total),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
