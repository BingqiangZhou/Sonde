import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';

part 'custom_adaptive_navigation_sidebar.dart';
part 'custom_adaptive_navigation_items.dart';
part 'custom_adaptive_navigation_mobile.dart';

const Duration _kBottomAccessoryPaddingTransition = AppDurations.navigationTransition;

class CustomAdaptiveNavigation extends ConsumerStatefulWidget {
  const CustomAdaptiveNavigation({
    required this.destinations, required this.selectedIndex, required this.onDestinationSelected, super.key,
    this.body,
    this.floatingActionButton,
    this.appBar,
    this.bottomAccessory,
    this.bottomAccessoryBodyPadding = 60,
    this.mobileOverlayReserve,
    this.mobileNavDockInset = 12,
    this.mobileNavBarHeight = 60,
    this.globalOverlayBodyPadding = 0,
    this.desktopNavExpanded = true,
    this.onDesktopNavToggle,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final Widget? bottomAccessory;
  final double bottomAccessoryBodyPadding;

  /// Vertical space reserved below the body for a feature-owned floating
  /// overlay such as the global player dock (safe-area + dock height +
  /// gap). Callers that know the overlay geometry should pass it; when
  /// null a default matching the standard mobile dock is reserved.
  final double? mobileOverlayReserve;

  /// Horizontal and bottom inset of the floating mobile nav dock.
  final double mobileNavDockInset;

  /// Visual height of the mobile nav bar content.
  final double mobileNavBarHeight;

  final double globalOverlayBodyPadding;
  final bool desktopNavExpanded;
  final VoidCallback? onDesktopNavToggle;

  @override
  ConsumerState<CustomAdaptiveNavigation> createState() => _CustomAdaptiveNavigationState();
}

class _CustomAdaptiveNavigationState extends ConsumerState<CustomAdaptiveNavigation> {
  late final ValueNotifier<bool> _sidebarExpanded;
  late final PageController _pageController;

  static const String _sidebarExpandedKey = 'sidebar_expanded';

  @override
  void initState() {
    super.initState();
    // Initialize sidebar state from local storage
    _sidebarExpanded = ValueNotifier<bool>(widget.desktopNavExpanded);
    _pageController = PageController(initialPage: widget.selectedIndex);
    _loadSidebarState();
  }

  Future<void> _loadSidebarState() async {
    final saved =
        await ref.read(localStorageServiceProvider).getBool(_sidebarExpandedKey);
    if (saved != null) {
      _sidebarExpanded.value = saved;
    }
  }

  Future<void> _toggleSidebar() async {
    _sidebarExpanded.value = !_sidebarExpanded.value;
    await ref
        .read(localStorageServiceProvider)
        .saveBool(_sidebarExpandedKey, _sidebarExpanded.value);
  }

  void _handlePageChanged(int index) {
    if (index != widget.selectedIndex) {
      widget.onDestinationSelected?.call(index);
      // Trigger haptic feedback on iOS
      AdaptiveHaptic.lightImpact();
    }
  }

  @override
  void didUpdateWidget(covariant CustomAdaptiveNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with external state changes if needed
    if (oldWidget.desktopNavExpanded != widget.desktopNavExpanded) {
      _sidebarExpanded.value = widget.desktopNavExpanded;
    }
    // Sync PageController when selectedIndex changes externally (e.g., by GoRouter)
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _pageController.hasClients &&
        widget.destinations.length > 1) {
      _pageController.jumpToPage(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _sidebarExpanded.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < Breakpoints.medium) {
          return _buildMobileLayout(context, width);
        }
        if (width < Breakpoints.mediumLarge) {
          return _buildTabletLayout(context);
        }
        return _buildDesktopLayout(context);
      },
    );
  }

  /// Default overlay reserve when the caller does not supply one:
  /// safe-area bottom (or 12 inset) + 60 dock height + 2 gap.
  static double _defaultMobileOverlayReserve(BuildContext context) {
    final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;
    return (safeAreaBottom > 0.0 ? safeAreaBottom : 12) + 60 + 2;
  }

  Widget _buildMobileLayout(BuildContext context, double width) {
    final dockReserve =
        widget.mobileOverlayReserve ?? _defaultMobileOverlayReserve(context);
    final accessoryBodyPadding = widget.bottomAccessory != null
        ? widget.bottomAccessoryBodyPadding
        : 0.0;
    final totalBottomReserve = dockReserve + accessoryBodyPadding + widget.globalOverlayBodyPadding;

    // Apple platforms: Use PageView for tab swipe gesture
    final shouldUsePageView = PlatformHelper.isApple(context) &&
        widget.destinations.length > 1;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: widget.appBar,
      body: Stack(
        children: [
          Stack(
            children: [
              RepaintBoundary(
                child: AnimatedPadding(
                  duration: _kBottomAccessoryPaddingTransition,
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: totalBottomReserve,
                  ),
                  child: shouldUsePageView
                      ? PageView(
                          controller: _pageController,
                          onPageChanged: _handlePageChanged,
                          physics: const BouncingScrollPhysics(),
                          children: _buildPageViewChildren(),
                        )
                      : (widget.body ?? const SizedBox.shrink()),
                ),
              ),
              if (widget.floatingActionButton != null)
                Positioned(
                  right: context.spacing.mdLg,
                  bottom: accessoryBodyPadding + widget.globalOverlayBodyPadding + 108,
                  child: widget.floatingActionButton!,
                ),
              if (widget.bottomAccessory != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: dockReserve,
                  child: widget.bottomAccessory!,
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(
                widget.mobileNavDockInset,
                0,
                widget.mobileNavDockInset,
                widget.mobileNavDockInset,
              ),
              child: Align(
                child: _CleanDock(
                  key: const Key('custom_adaptive_navigation_mobile_dock'),
                  width: width < Breakpoints.mini
                      ? width - (widget.mobileNavDockInset * 2)
                      : 396,
                  child: _buildMobileNavBar(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build PageView children for iOS tab swipe gesture.
  /// Only the selected page renders the actual body to avoid
  /// duplicate GlobalKey errors from StatefulNavigationShell.
  List<Widget> _buildPageViewChildren() {
    return List<Widget>.generate(
      widget.destinations.length,
      (index) => index == widget.selectedIndex
          ? (widget.body ?? const SizedBox.shrink())
          : const SizedBox.expand(),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.appBar,
      body: Row(
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.spacing.xs, context.spacing.md, context.spacing.xs, context.spacing.md),
              child: _CleanSidebar(
                expanded: false,
                child: Column(
                  children: [
                    SizedBox(height: context.spacing.md),
                    _buildBrandLogoBadge(context),
                    SizedBox(height: context.spacing.md),
                    ..._buildNavigationItems(context, compact: true),
                    const Spacer(),
                    if (widget.destinations.isNotEmpty)
                      _buildProfileNavigationItem(context, compact: true),
                    SizedBox(height: context.spacing.smMd),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.smMd),
          Expanded(
            child: _buildContentStack(
              bottomPadding:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0),
              fabBottom:
                  widget.globalOverlayBodyPadding +
                  (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0) +
                  context.spacing.xl,
            ),
          ),
          SizedBox(width: context.spacing.smMd),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final isApple = PlatformHelper.isApple(context);
    final contentPadding = EdgeInsets.fromLTRB(
      0,
      context.spacing.md,
      context.spacing.md,
      context.spacing.md,
    );
    final contentBottomPadding =
        widget.globalOverlayBodyPadding +
        (widget.bottomAccessory != null ? widget.bottomAccessoryBodyPadding : 0);
    final fabBottom = contentBottomPadding + context.spacing.xl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.appBar,
      body: Row(
        children: [
          if (isApple)
            _buildAppleSidebarAnimated(context)
          else
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _sidebarExpanded,
                builder: (context, expanded, child) {
                  return RepaintBoundary(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: expanded ? 240 : 72),
                      duration: AppDurations.navigationTransition,
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedWidth, child) {
                        final showCompact = animatedWidth < 120;
                        return SizedBox(
                          key: const ValueKey('desktop_navigation_sidebar'),
                          width: animatedWidth,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(showCompact ? context.spacing.xs : context.spacing.smMd, context.spacing.md, showCompact ? context.spacing.xs : context.spacing.smMd, context.spacing.md),
                            child: _CleanSidebar(
                              expanded: expanded,
                              child: showCompact
                                  ? _buildDesktopCollapsedSidebar(context)
                                  : _buildDesktopExpandedSidebar(context),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: Padding(
              padding: contentPadding,
              child: _buildContentStack(
                bottomPadding: contentBottomPadding,
                fabBottom: fabBottom,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStack({
    required double bottomPadding,
    required double fabBottom,
  }) {
    return Stack(
      children: [
        RepaintBoundary(
          child: AnimatedPadding(
            duration: _kBottomAccessoryPaddingTransition,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: widget.body ?? const SizedBox.shrink(),
          ),
        ),
        if (widget.floatingActionButton != null)
          Positioned(
            right: context.spacing.mdLg,
            bottom: fabBottom,
            child: widget.floatingActionButton!,
          ),
        if (widget.bottomAccessory != null)
          Positioned(left: 0, right: 0, bottom: 0, child: widget.bottomAccessory!),
      ],
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    required this.child, super.key,
    this.alignment,
    this.maxWidth,
    this.padding,
    this.avoidTopSafeArea = false,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  /// When true on iOS, skip adding the safe area top inset to padding.
  /// Use with AdaptiveSliverAppBar (CupertinoSliverNavigationBar) which
  /// already handles the safe area internally.
  final bool avoidTopSafeArea;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tokens = Theme.of(context).extension<AppThemeExtension>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppThemeExtension.dark
            : AppThemeExtension.light);

    final topPadding = (avoidTopSafeArea && PlatformHelper.isApple(context))
        ? 0.0
        : MediaQuery.viewPaddingOf(context).top;
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          width < Breakpoints.medium ? context.spacing.md : context.spacing.lg,
          (width < Breakpoints.medium ? context.spacing.smMd : context.spacing.mdLg) + topPadding,
          width < Breakpoints.medium ? context.spacing.md : context.spacing.lg,
          0,
        );
    final resolvedMaxWidth = maxWidth ??
        (width < Breakpoints.medium
            ? width
            : width < Breakpoints.mediumLarge
                ? 920
                : tokens.contentMaxWidth);

    return Align(
      alignment: alignment ?? Alignment.topCenter,
      child: Padding(
        padding: resolvedPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// macOS-native sidebar with vibrancy (backdrop blur + translucent surface)
