part of 'custom_adaptive_navigation.dart';

extension _CustomAdaptiveNavigationSidebar on _CustomAdaptiveNavigationState {

  Widget _buildAppleSidebarAnimated(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _sidebarExpanded,
      builder: (context, expanded, _) {
        return RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: expanded ? 220 : 64),
            duration: AppDurations.navigationTransition,
            curve: Curves.easeOutCubic,
            builder: (context, animatedWidth, _) {
              final showCompact = animatedWidth < 120;
              return SizedBox(
                key: const ValueKey('apple_desktop_sidebar'),
                width: animatedWidth,
                child: _AppleSidebarContainer(
                  child: showCompact
                      ? _buildAppleSidebarCompact(context)
                      : _buildAppleSidebarExpanded(context),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAppleSidebarExpanded(BuildContext context) {
    return Column(
      children: [
        // Brand header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              _buildBrandLogoBadge(context),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.sidebarAppTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              _buildAppleSidebarToggle(context, Icons.chevron_left),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Main navigation items
        ...List.generate(
          widget.destinations.length > 1
              ? widget.destinations.length - 1
              : widget.destinations.length,
          (index) => _buildAppleSidebarItem(context, index, compact: false),
        ),
        const Spacer(),
        // Separator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildAppleSeparator(context),
        ),
        // Profile item
        if (widget.destinations.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: _buildAppleSidebarItem(
              context,
              widget.destinations.length - 1,
              compact: false,
            ),
          ),
      ],
    );
  }

  Widget _buildAppleSidebarCompact(BuildContext context) {
    return Column(
      children: [
        // Brand logo
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
          child: _buildBrandLogoBadge(context),
        ),
        _buildAppleSidebarToggle(context, Icons.chevron_right),
        const SizedBox(height: 4),
        // Main navigation items
        ...List.generate(
          widget.destinations.length > 1
              ? widget.destinations.length - 1
              : widget.destinations.length,
          (index) => _buildAppleSidebarItem(context, index, compact: true),
        ),
        const Spacer(),
        // Separator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: _buildAppleSeparator(context),
        ),
        // Profile item
        if (widget.destinations.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: _buildAppleSidebarItem(
              context,
              widget.destinations.length - 1,
              compact: true,
            ),
          ),
      ],
    );
  }

  Widget _buildAppleSidebarToggle(BuildContext context, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _toggleSidebar,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Tooltip(
            message: icon == Icons.chevron_left
                ? context.l10n.sidebarCollapseMenu
                : context.l10n.sidebarExpandMenu,
            child: Icon(
              icon,
              size: 13,
              color: isDark
                  ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppleSeparator(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildAppleSidebarItem(
    BuildContext context,
    int index, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = index == widget.selectedIndex;
    final destination = widget.destinations[index];

    final selectedBgColor = isDark
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.12);
    const selectedIconColor = AppColors.primary;
    final selectedTextColor = theme.colorScheme.onSurface;
    final unselectedIconColor = theme.colorScheme.onSurfaceVariant;
    final unselectedTextColor = theme.colorScheme.onSurfaceVariant;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Semantics(
          button: true,
          selected: isSelected,
          label: destination.label,
          child: Tooltip(
            message: destination.label,
            child: _NavInkWell(
              onTap: () => widget.onDestinationSelected?.call(index),
              borderRadius: AppRadius.sm,
              isSelected: isSelected,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? selectedBgColor : null,
                  borderRadius: AppRadius.smRadius,
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      size: 18,
                      color: isSelected
                          ? selectedIconColor
                          : unselectedIconColor,
                    ),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: destination.label,
        child: _NavInkWell(
          onTap: () => widget.onDestinationSelected?.call(index),
          borderRadius: AppRadius.sm,
          isSelected: isSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : null,
              borderRadius: AppRadius.smRadius,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: FittedBox(
                    child: IconTheme(
                      data: IconThemeData(
                        color: isSelected
                            ? selectedIconColor
                            : unselectedIconColor,
                      ),
                      child: isSelected
                          ? (destination.selectedIcon ?? destination.icon)
                          : destination.icon,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium!.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected
                          ? selectedTextColor
                          : unselectedTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopExpandedSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(context.spacing.smMd, context.spacing.smMd, context.spacing.smMd, context.spacing.sm),
          child: Row(
            children: [
              _buildBrandLogoBadge(context),
              SizedBox(width: context.spacing.smMd),
              Expanded(
                child: Text(
                  l10n.sidebarAppTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _toggleSidebar,
                tooltip: l10n.sidebarCollapseMenu,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        SizedBox(height: context.spacing.sm),
        ..._buildNavigationItems(context, compact: false),
        const Spacer(),
        if (widget.destinations.isNotEmpty)
          _buildProfileNavigationItem(context, compact: false),
      ],
    );
  }

  Widget _buildDesktopCollapsedSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        SizedBox(height: context.spacing.smMd),
        _buildBrandLogoBadge(context),
        IconButton(
          onPressed: _toggleSidebar,
          tooltip: l10n.sidebarExpandMenu,
          icon: const Icon(Icons.chevron_right),
        ),
        SizedBox(height: context.spacing.sm),
        ..._buildNavigationItems(context, compact: true),
        const Spacer(),
        if (widget.destinations.isNotEmpty)
          _buildProfileNavigationItem(context, compact: true),
      ],
    );
  }

  Widget _buildBrandLogoBadge(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: ClipRRect(
        borderRadius: AppRadius.smRadius,
        child: Image.asset('assets/icons/Logo3.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _AppleSidebarContainer extends StatelessWidget {
  const _AppleSidebarContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? CupertinoColors.systemBackground.darkColor.withValues(alpha: 0.75)
        : CupertinoColors.systemBackground.color.withValues(alpha: 0.80);
    final borderColor = isDark
        ? CupertinoColors.separator.darkColor
        : CupertinoColors.separator.color;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: BorderDirectional(
              end: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Arc+Linear style sidebar with theme-aware surface
class _CleanSidebar extends StatelessWidget {
  const _CleanSidebar({required this.child, required this.expanded});

  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
        borderRadius: expanded
            ? const BorderRadiusDirectional.horizontal(end: Radius.circular(AppRadius.lg))
            : AppRadius.lgXlRadius,
      ),
      child: child,
    );
  }
}

/// Nav item ink well with hover effect
