import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/custom_adaptive_navigation.dart';
import 'package:sonde/core/widgets/keyboard_shortcuts.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_feed_providers.dart';

/// Shell widget for the main tab navigation using StatefulShellRoute.
///
/// Replaces the old `HomePage` which used local `IndexedStack` + `setState`.
/// GoRouter's `StatefulNavigationShell` now manages branch state persistence.
class HomeShellWidget extends ConsumerStatefulWidget {

  const HomeShellWidget({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShellWidget> createState() => _HomeShellWidgetState();
}

class _HomeShellWidgetState extends ConsumerState<HomeShellWidget> {
  bool _desktopNavExpanded = true;
  bool _hasPrefetchedLibraryFeed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _prefetchLibraryFeedOnHomeEnter();
    });
  }

  void _prefetchLibraryFeedOnHomeEnter() {
    if (_hasPrefetchedLibraryFeed) {
      return;
    }
    _hasPrefetchedLibraryFeed = true;

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      return;
    }

    final feedState = ref.read(podcastFeedProvider);
    if (feedState.episodes.isNotEmpty && feedState.isDataFresh()) {
      return;
    }

    unawaited(
      ref.read(podcastFeedProvider.notifier).loadInitialFeed(background: true),
    );
  }

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    final l10n = context.l10n;
    return [
      NavigationDestination(
        icon: const Icon(Icons.travel_explore_outlined),
        selectedIcon: const Icon(Icons.travel_explore),
        label: l10n.nav_podcast,
      ),
      NavigationDestination(
        icon: const Icon(Icons.library_books_outlined),
        selectedIcon: const Icon(Icons.library_books),
        label: l10n.nav_feed,
      ),
      NavigationDestination(
        icon: const Icon(Icons.newspaper_outlined),
        selectedIcon: const Icon(Icons.newspaper),
        label: l10n.site_reading_tab,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.nav_profile,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AppKeyboardShortcuts(
      onTabSwitch: _handleNavigation,
      child: CustomAdaptiveNavigation(
        key: const ValueKey('home_custom_adaptive_navigation'),
        destinations: _buildDestinations(context),
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _handleNavigation,
        floatingActionButton: _buildFloatingActionButton(),
        desktopNavExpanded: _desktopNavExpanded,
        onDesktopNavToggle: () {
          setState(() {
            _desktopNavExpanded = !_desktopNavExpanded;
          });
        },
        body: widget.navigationShell,
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return null;
  }

  void _handleNavigation(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
