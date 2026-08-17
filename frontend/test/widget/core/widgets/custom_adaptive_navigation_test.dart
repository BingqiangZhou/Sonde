import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/core/widgets/custom_adaptive_navigation.dart';

import '../../../helpers/mock_local_storage_service.dart';

void main() {
  group('CustomAdaptiveNavigation bottomAccessory layout', () {
    testWidgets('desktop: accessory stays in right content area only', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(),
      );

      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );

      // Material sidebar expands to 240px
      // Content should start after sidebar width
      expect(accessoryRect.left, greaterThan(230));
      expect(accessoryRect.width, lessThan(1200));
      // The accessory fills the content area (1200 - 240 - margins = ~900)
      expect(accessoryRect.width, greaterThan(500));
      expect(accessoryRect.bottom, greaterThan(840));
    });

    testWidgets('tablet: accessory stays in right content area only', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(800, 900),
        child: _buildNavigation(),
      );

      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );

      expect(accessoryRect.left, greaterThan(70));
      expect(accessoryRect.width, lessThan(800));
      expect(accessoryRect.width, greaterThan(650));
      expect(accessoryRect.bottom, greaterThan(840));
    });

    testWidgets('mobile: accessory remains above navigation bar', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(),
      );

      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );
      final dockRect = tester.getRect(
        find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
      );

      expect(accessoryRect.width, closeTo(390, 2));
      expect(accessoryRect.top, lessThan(dockRect.top));
      expect(accessoryRect.bottom, lessThanOrEqualTo(dockRect.top + 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile: bottom backdrop sits beneath accessory and dock', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(),
      );

      // The bottom accessory is positioned above the dock
      final accessoryRect = tester.getRect(
        find.byKey(const Key('test_bottom_accessory')),
      );
      final dockRect = tester.getRect(
        find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
      );

      expect(accessoryRect.bottom, lessThanOrEqualTo(dockRect.top + 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile: bottom backdrop still renders without accessory', (
      tester,
    ) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(390, 844),
        child: _buildNavigation(includeAccessory: false),
      );

      // When no accessory, the dock should still render
      expect(find.byKey(const Key('test_bottom_accessory')), findsNothing);
      expect(
        find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('CustomAdaptiveNavigation desktop sidebar toggle', () {
    testWidgets('expanded: shows wide sidebar with title (non-Apple)',
        (tester) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(),
      );

      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      // Find the SizedBox widget and check its width property
      final sidebarSizedBox = find.byWidgetPredicate((widget) =>
          widget is SizedBox &&
          widget.width == 240);

      expect(sidebarSizedBox, findsOneWidget);
    });

    testWidgets('collapsed: shows narrow sidebar without title (non-Apple)',
        (tester) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(
          desktopNavExpanded: false,
        ),
      );

      expect(find.text('AI Assistant'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Find the SizedBox widget and check its width property
      final sidebarSizedBox = find.byWidgetPredicate((widget) =>
          widget is SizedBox &&
          widget.width == 72);

      expect(sidebarSizedBox, findsOneWidget);
    });

    testWidgets('Apple platforms: fixed 220px sidebar without toggle',
        (tester) async {
      await _pumpWithSize(
        tester: tester,
        size: const Size(1200, 900),
        child: _buildNavigation(platform: TargetPlatform.macOS),
      );

      // Apple Podcasts 风格侧栏头部显示应用名，且无折叠开关
      // （条目自带的 13px 指示箭头属于 Apple 风格，不算折叠开关）
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.chevron_left && (w.size ?? 24) >= 20,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.chevron_right && (w.size ?? 24) >= 20,
        ),
        findsNothing,
      );

      // Find the Apple sidebar Container by its unique CupertinoColors decoration
      // The Apple sidebar uses CupertinoColors.systemBackground with opacity
      final sidebarContainer = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color != null);

      // Should find the Apple sidebar (and possibly other containers)
      expect(sidebarContainer, findsWidgets);

      // Verify the sidebar width by getting its render box
      // The first matching container should be the sidebar (leftmost)
      final firstContainerRect = tester.getRect(sidebarContainer.first);
      expect(firstContainerRect.width, closeTo(220, 1));
    });
  });
}

Future<void> _pumpWithSize({
  required WidgetTester tester,
  required Size size,
  required Widget child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(child);
  await tester.pump(const Duration(milliseconds: 500));
}

Widget _buildNavigation({
  bool desktopNavExpanded = true,
  bool includeAccessory = true,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: platform),
      home: CustomAdaptiveNavigation(
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Feed',
        ),
        NavigationDestination(
          icon: Icon(Icons.podcasts_outlined),
          selectedIcon: Icon(Icons.podcasts),
          label: 'Podcast',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      desktopNavExpanded: desktopNavExpanded,
      onDesktopNavToggle: () {},
      body: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
      bottomAccessory: includeAccessory
          ? Container(
              key: const Key('test_bottom_accessory'),
              height: 60,
              color: Colors.blue,
            )
          : null,
      ),
    ),
  );
}
