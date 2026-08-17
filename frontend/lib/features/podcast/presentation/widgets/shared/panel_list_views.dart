import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';

/// Shared page skeleton for panel-style list pages (history,
/// subscriptions, highlights, downloads, daily report).
///
/// Scaffold > transparent Material > ResponsiveContainer (maxWidth
/// [kPanelListMaxWidth]) > optional adaptive pull-to-refresh > optional
/// Scrollbar > CustomScrollView with an [AdaptiveSliverAppBar], a top gap
/// and the page's state slivers.
class PanelListPageScaffold extends StatelessWidget {
  const PanelListPageScaffold({
    required this.appBarTitle,
    required this.slivers,
    super.key,
    this.scaffoldKey,
    this.appBarActions,
    this.scrollController,
    this.showScrollbar = true,
    this.onRefresh,
    this.topGap,
  });

  /// Key applied to the page [Scaffold] (route/test identity).
  final Key? scaffoldKey;

  /// Title displayed in the adaptive app bar.
  final String appBarTitle;

  /// Action buttons displayed in the adaptive app bar.
  final List<Widget>? appBarActions;

  /// Scroll controller attached to the custom scroll view.
  final ScrollController? scrollController;

  /// Whether to wrap the scroll view in a [Scrollbar] when a
  /// [scrollController] is provided.
  final bool showScrollbar;

  /// Pull-to-refresh callback. When non-null the scroll view is wrapped in
  /// [AdaptiveRefreshIndicator.sliver].
  final Future<void> Function()? onRefresh;

  /// Height of the gap between the app bar and the first state sliver.
  /// Defaults to [AppSpacing.smMd].
  final double? topGap;

  /// Page state slivers rendered after the app bar gap.
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: ResponsiveContainer(
          maxWidth: kPanelListMaxWidth,
          avoidTopSafeArea: true,
          alignment: Alignment.topCenter,
          child: _buildScrollable(context),
        ),
      ),
    );
  }

  Widget _buildScrollable(BuildContext context) {
    final onRefresh = this.onRefresh;
    if (onRefresh == null) {
      return _buildScrollView(context, null);
    }

    return AdaptiveRefreshIndicator.sliver(
      onRefresh: onRefresh,
      builder: _buildScrollView,
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildScrollView(BuildContext context, Widget? refreshSliver) {
    final scrollController = this.scrollController;
    final scrollView = CustomScrollView(
      controller: scrollController,
      slivers: [
        ?refreshSliver,
        AdaptiveSliverAppBar(
          title: appBarTitle,
          actions: appBarActions,
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: topGap ?? context.spacing.smMd),
        ),
        ...slivers,
      ],
    );

    if (scrollController == null || !showScrollbar) {
      return scrollView;
    }

    return Scrollbar(controller: scrollController, child: scrollView);
  }
}

/// Full-height panel for loading / error / empty page states, rendered
/// inside a [SliverFillRemaining].
///
/// Boxed variant: [SurfacePanel] with a section header + divider and the
/// body filling the remaining space.
/// Bare variant ([bare] = true): header + centered body without the
/// surface box — used for loading states to avoid a panel flash before
/// content arrives.
class PanelStateView extends StatelessWidget {
  const PanelStateView({
    required this.title,
    required this.body,
    super.key,
    this.subtitle,
    this.trailing,
    this.hideTitle = false,
    this.bare = false,
    this.bareBodyGap = false,
    this.centerBody = true,
    this.headerPadding,
  });

  /// Section header title (page or panel heading).
  final String title;

  /// Section header subtitle (usually the l10n loading/error/empty hint).
  final String? subtitle;

  /// Optional trailing widget in the section header.
  final Widget? trailing;

  /// Whether to hide the section header title (subtitle only).
  final bool hideTitle;

  /// State body filling the remaining panel space.
  final Widget body;

  /// Whether to skip the [SurfacePanel] box and divider.
  final bool bare;

  /// Whether to insert an extra gap between the header and the body in the
  /// bare variant.
  final bool bareBodyGap;

  /// Whether the body is centered (default) or padded and top-aligned.
  final bool centerBody;

  /// Overrides the section header padding.
  final EdgeInsetsGeometry? headerPadding;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding:
          headerPadding ??
          EdgeInsets.fromLTRB(
            context.spacing.mdLg,
            context.spacing.md,
            context.spacing.mdLg,
            context.spacing.smMd,
          ),
      child: AppSectionHeader(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        hideTitle: hideTitle,
      ),
    );

    if (bare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (bareBodyGap) SizedBox(height: context.spacing.mdLg),
          Expanded(child: Center(child: body)),
        ],
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: appThemeOf(context).cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: centerBody
                ? body
                : Padding(
                    padding: EdgeInsets.all(context.spacing.mdLg),
                    child: Align(alignment: Alignment.topLeft, child: body),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a full-height state view in a [SliverFillRemaining].
List<Widget> panelStateSlivers(Widget child) {
  return [SliverFillRemaining(hasScrollBody: false, child: child)];
}

/// Builds the data-state slivers of a panel list page: rounded header cap
/// (section header + divider), [itemSlivers], rounded bottom cap and a
/// bottom buffer sliver.
List<Widget> panelDataSlivers(
  BuildContext context, {
  required String title,
  required List<Widget> itemSlivers,
  String? subtitle,
  Widget? trailing,
  bool hideTitle = false,
  EdgeInsetsGeometry? headerPadding,
  double? bottomBuffer,
}) {
  final theme = Theme.of(context);
  final tokens = appThemeOf(context);

  return [
    // Header cap with top rounded corners
    SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(tokens.cardRadius),
            topRight: Radius.circular(tokens.cardRadius),
          ),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  headerPadding ??
                  EdgeInsets.fromLTRB(
                    context.spacing.mdLg,
                    context.spacing.md,
                    context.spacing.mdLg,
                    context.spacing.smMd,
                  ),
              child: AppSectionHeader(
                title: title,
                subtitle: subtitle,
                trailing: trailing,
                hideTitle: hideTitle,
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.45,
              ),
            ),
          ],
        ),
      ),
    ),
    ...itemSlivers,
    // Bottom cap with bottom rounded corners
    SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(tokens.cardRadius),
            bottomRight: Radius.circular(tokens.cardRadius),
          ),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        height: context.spacing.smMd,
      ),
    ),
    // Bottom buffer
    SliverPadding(
      padding: EdgeInsets.only(bottom: bottomBuffer ?? context.spacing.xl),
    ),
  ];
}

/// Centered error body: optional icon + message + optional retry button.
Widget panelErrorBody(
  BuildContext context, {
  required String message,
  IconData? icon = Icons.error_outline,
  double iconSize = 56,
  TextStyle? messageStyle,
  String? retryLabel,
  VoidCallback? onRetry,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: iconSize, color: Theme.of(context).colorScheme.error),
        SizedBox(height: context.spacing.lg),
      ],
      Text(
        message,
        style: messageStyle ?? Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
      if (retryLabel != null && onRetry != null) ...[
        SizedBox(height: context.spacing.md),
        FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
      ],
    ],
  );
}

/// Centered empty body: icon + optional title + optional subtitle.
Widget panelEmptyBody(
  BuildContext context, {
  required IconData icon,
  double iconSize = 56,
  double? gap,
  String? title,
  String? subtitle,
}) {
  final theme = Theme.of(context);

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: iconSize, color: theme.colorScheme.onSurfaceVariant),
      SizedBox(height: gap ?? context.spacing.lg),
      if (title != null)
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      if (subtitle != null) ...[
        if (title != null) SizedBox(height: context.spacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}

/// Small boxed note used inside panel empty-state bodies.
Widget panelNoteBox(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);

  return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.xxlCardRadius,
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
      ),
    ),
    padding: EdgeInsets.all(context.spacing.md),
    child: child,
  );
}
