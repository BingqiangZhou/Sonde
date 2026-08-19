import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/widgets/app_dialog.dart';
import 'package:sonde/core/widgets/app_dialog_helper.dart';

Widget _host(Future<void> Function(BuildContext context) onOpen) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const Key('open_dialog'),
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders title, content and actions, OK pops the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (context) => showAppDialog<void>(
          context: context,
          builder: (dialogContext) => AppDialog(
            title: const Text('Dialog Title'),
            content: const Text('Dialog body text'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();

    expect(find.text('Dialog Title'), findsOneWidget);
    expect(find.text('Dialog body text'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('renders without a title for status dialogs', (tester) async {
    await tester.pumpWidget(
      _host(
        (context) => showAppDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => const AppDialog(
            content: Text('Clearing cache...'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();

    expect(find.text('Clearing cache...'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('stretches actions to equal widths on mobile', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        (context) => showAppDialog<void>(
          context: context,
          builder: (dialogContext) => AppDialog(
            title: const Text('Title'),
            content: const Text('Body'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();

    // Dialog fills the screen width minus the 16px inset padding per side.
    expect(tester.getSize(find.byType(AppDialog)).width, 388.0);
    // Mobile actions are an equally stretched row, not an overflow bar.
    expect(find.byType(OverflowBar), findsNothing);
    final cancelSize = tester.getSize(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final confirmSize = tester.getSize(
      find.widgetWithText(TextButton, 'Confirm'),
    );
    expect(cancelSize.width, confirmSize.width);
    expect(cancelSize.width, greaterThan(150));
  });

  testWidgets('uses an end-aligned overflow bar for actions on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (context) => showAppDialog<void>(
          context: context,
          builder: (dialogContext) => AppDialog(
            title: const Text('Title'),
            content: const Text('Body'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();

    expect(find.byType(OverflowBar), findsOneWidget);
    expect(tester.getSize(find.byType(AppDialog)).width, 560.0);
  });

  testWidgets('confirmation dialog localizes buttons and returns the result', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _host((context) async {
        result = await showAppConfirmationDialog(
          context: context,
          title: 'Delete item?',
          message: 'This cannot be undone.',
        );
      }),
    );

    // Confirm path.
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
    expect(find.text('Delete item?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    // Cancel path.
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Dismiss-on-barrier path.
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('destructive confirmation styles the confirm button with error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (context) => showAppConfirmationDialog(
          context: context,
          title: 'Clear cache?',
          message: 'All cached files will be removed.',
          isDestructive: true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AppDialog)));
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Confirm'),
    );
    expect(
      button.style?.foregroundColor?.resolve(const <WidgetState>{}),
      theme.colorScheme.error,
    );
  });
}
