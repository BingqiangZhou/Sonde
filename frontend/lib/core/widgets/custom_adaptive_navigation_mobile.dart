part of 'custom_adaptive_navigation.dart';

extension _CustomAdaptiveNavigationMobile on _CustomAdaptiveNavigationState {

  Widget _buildMobileNavBar(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      return _buildIOSMobileNavBar(context);
    }
    return SizedBox(
      key: const Key('custom_adaptive_navigation_mobile_nav_bar'),
      height: widget.mobileNavBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.destinations.length, (index) {
          final destination = widget.destinations[index];
          final isSelected = index == widget.selectedIndex;
          return Expanded(
            child: _buildMobileNavItem(
              context,
              destination,
              isSelected,
              () => widget.onDestinationSelected?.call(index),
            ),
          );
        }),
      ),
    );
  }

  /// iOS-style bottom navigation (CupertinoTabBar aesthetic).
  /// Uses system icon colors instead of gradient background.
  Widget _buildIOSMobileNavBar(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: widget.mobileNavBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.destinations.length, (index) {
          final destination = widget.destinations[index];
          final isSelected = index == widget.selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                // Update PageController for iOS swipe gesture
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(index);
                }
                widget.onDestinationSelected?.call(index);
              },
              onDoubleTap: isSelected
                  ? () {
                      AdaptiveHaptic.lightImpact();
                      // Scroll to top via PrimaryScrollController
                      PrimaryScrollController.of(context).animateTo(
                        0,
                        duration: AppDurations.scrollAnimation,
                        curve: Curves.easeOut,
                      );
                    }
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        size: 22,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      child: isSelected
                          ? (destination.selectedIcon ?? destination.icon)
                          : destination.icon,
                    ),
                    SizedBox(height: context.spacing.xxs),
                    Text(
                      destination.label,
                      style: AppTextStyles.navLabel(
                        isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMobileNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: AdaptiveInkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdLgRadius,
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: AppDurations.scaleFast,
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.md,
                      vertical: context.spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: AppColors.violetColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: AppRadius.mdLgRadius,
                    ),
                    child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                  child: isSelected
                      ? (destination.selectedIcon ?? destination.icon)
                      : destination.icon,
                ),
                  ),
                ),
                SizedBox(height: context.spacing.xxs),
                Text(
                  destination.label,
                  style: AppTextStyles.navLabel(
                    isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CleanDock extends StatelessWidget {
  const _CleanDock({required this.child, required this.width, super.key});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.9),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
