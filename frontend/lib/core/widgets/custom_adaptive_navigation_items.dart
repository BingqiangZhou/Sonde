part of 'custom_adaptive_navigation.dart';

extension _CustomAdaptiveNavigationItems on _CustomAdaptiveNavigationState {
  List<Widget> _buildNavigationItems(
    BuildContext context, {
    required bool compact,
  }) {
    if (widget.destinations.length <= 1) {
      return const <Widget>[];
    }

    final items = <Widget>[];
    for (var index = 0; index < widget.destinations.length - 1; index++) {
      final destination = widget.destinations[index];
      final isSelected = index == widget.selectedIndex;
      items.add(
        _buildNavItem(
          context,
          destination,
          isSelected,
          compact,
          () => widget.onDestinationSelected?.call(index),
        ),
      );
    }
    return items;
  }

  Widget _buildProfileNavigationItem(
    BuildContext context, {
    required bool compact,
  }) {
    final profileIndex = widget.destinations.length - 1;
    final destination = widget.destinations[profileIndex];
    final isSelected = profileIndex == widget.selectedIndex;
    return _buildNavItem(
      context,
      destination,
      isSelected,
      compact,
      () => widget.onDestinationSelected?.call(profileIndex),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    bool compact,
    VoidCallback onTap,
  ) {
    if (compact) {
      return _buildCompactNavItem(
        context,
        destination,
        isSelected,
        onTap,
      );
    }
    return _buildExpandedNavItem(
      context,
      destination,
      isSelected,
      onTap,
    );
  }

  Widget _buildCompactNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final extension = appThemeOf(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.xs, vertical: context.spacing.xs),
          child: _NavInkWell(
            onTap: onTap,
            borderRadius: extension.navItemRadius,
            isSelected: isSelected,
            child: AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: AppDurations.scaleFast,
              curve: Curves.easeOutCubic,
              child: Container(
                width: 44,
                height: 44,
                decoration: _buildNavDecoration(isSelected: isSelected, context: context),
                child: Center(
                  child: IconTheme(
                    data: const IconThemeData(size: 20),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedNavItem(
    BuildContext context,
    NavigationDestination destination,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.xs),
        child: _NavInkWell(
          onTap: onTap,
          borderRadius: extension.navItemRadius,
          isSelected: isSelected,
          child: AnimatedScale(
            scale: isSelected ? 1.02 : 1.0,
            duration: AppDurations.scaleFast,
            curve: Curves.easeOutCubic,
            child: Container(
              height: 56,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              decoration: _buildNavDecoration(isSelected: isSelected, context: context),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                  SizedBox(width: context.spacing.smMd),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildNavDecoration({
    required bool isSelected,
    required BuildContext context,
  }) {
    final extension = appThemeOf(context);
    if (isSelected) {
      // Gradient background for active state
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.violetColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(extension.navItemRadius),
      );
    }
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(extension.navItemRadius),
    );
  }
}

class _NavInkWell extends StatefulWidget {
  const _NavInkWell({
    required this.borderRadius,
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  final VoidCallback onTap;
  final double borderRadius;
  final bool isSelected;
  final Widget child;

  @override
  State<_NavInkWell> createState() => _NavInkWellState();
}

class _NavInkWellState extends State<_NavInkWell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final overlayColor = Theme.of(context).colorScheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: overlayColor.withValues(alpha: 0.12),
        highlightColor: overlayColor.withValues(alpha: 0.08),
        hoverColor: Colors.transparent, // We handle hover manually
        child: AnimatedContainer(
          duration: AppDurations.scaleFast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered && !widget.isSelected
                ? overlayColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Arc+Linear style dock with theme-aware surface + blur
