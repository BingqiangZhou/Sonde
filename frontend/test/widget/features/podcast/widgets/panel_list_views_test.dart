import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/panel_list_views.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('PanelListPageScaffold', () {
    testWidgets('renders app bar title, slivers and scaffold key',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PanelListPageScaffold(
            scaffoldKey: Key('panel_list_scaffold_test'),
            appBarTitle: 'Panel Title',
            slivers: [SliverToBoxAdapter(child: Text('panel body item'))],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('panel_list_scaffold_test')), findsOneWidget);
      expect(find.text('Panel Title'), findsOneWidget);
      expect(find.text('panel body item'), findsOneWidget);
      // No controller => no Scrollbar wrapper.
      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('wraps scroll view in Scrollbar when controller is provided',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          PanelListPageScaffold(
            appBarTitle: 'Panel Title',
            scrollController: controller,
            slivers: const [
              SliverToBoxAdapter(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
    });

    testWidgets('omits Scrollbar when showScrollbar is false', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          PanelListPageScaffold(
            appBarTitle: 'Panel Title',
            scrollController: controller,
            showScrollbar: false,
            slivers: const [
              SliverToBoxAdapter(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsNothing);
    });
  });

  group('PanelStateView', () {
    testWidgets('bare variant renders no SurfacePanel', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PanelStateView(
            title: 'State Title',
            subtitle: 'State Subtitle',
            bare: true,
            body: Text('loading body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SurfacePanel), findsNothing);
      expect(find.text('State Subtitle'), findsOneWidget);
      expect(find.text('loading body'), findsOneWidget);
    });

    testWidgets('boxed variant renders SurfacePanel with header and divider',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PanelStateView(
            title: 'State Title',
            subtitle: 'State Subtitle',
            body: Text('error body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SurfacePanel), findsOneWidget);
      expect(find.text('State Title'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('error body'), findsOneWidget);
    });

    testWidgets('hideTitle shows subtitle only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PanelStateView(
            title: 'State Title',
            subtitle: 'State Subtitle',
            hideTitle: true,
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('State Title'), findsNothing);
      expect(find.text('State Subtitle'), findsOneWidget);
    });
  });

  group('panelDataSlivers', () {
    testWidgets('renders header cap, items and divider', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => CustomScrollView(
              slivers: panelDataSlivers(
                context,
                title: 'Panel Title',
                subtitle: '3 items',
                itemSlivers: [
                  SliverList.builder(
                    itemCount: 2,
                    itemBuilder: (context, index) => ListTile(
                      key: Key('panel_item_$index'),
                      title: Text('Item $index'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel Title'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.byKey(const Key('panel_item_0')), findsOneWidget);
      expect(find.byKey(const Key('panel_item_1')), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('panelErrorBody', () {
    testWidgets('renders icon, message and retry button; retry fires',
        (tester) async {
      var retryTapped = false;

      await tester.pumpWidget(
        _wrap(
          Center(
            child: Builder(
              builder: (context) => panelErrorBody(
                context,
                message: 'Something went wrong',
                retryLabel: 'Retry',
                onRetry: () => retryTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryTapped, isTrue);
    });

    testWidgets('renders message only when icon and retry are omitted',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: Builder(
              builder: (context) => panelErrorBody(
                context,
                message: 'Just a message',
                icon: null,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Just a message'), findsOneWidget);
    });
  });

  group('panelEmptyBody', () {
    testWidgets('renders icon, title and subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: Builder(
              builder: (context) => panelEmptyBody(
                context,
                icon: Icons.history,
                title: 'Nothing here',
                subtitle: 'Come back later',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Come back later'), findsOneWidget);
    });
  });

  group('panelNoteBox', () {
    testWidgets('renders boxed child content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: Builder(
              builder: (context) => panelNoteBox(
                context,
                child: const Text('note content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('note content'), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });
  });
}
