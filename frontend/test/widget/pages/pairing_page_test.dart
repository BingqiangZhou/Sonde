import 'package:flutter/widgets.dart' show TextInputType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/features/pairing/domain/pairing_payload.dart';
import 'package:sonde/features/pairing/presentation/pages/pairing_page.dart';
import 'package:sonde/features/pairing/presentation/providers/pairing_provider.dart';
import '../../test_helpers.dart';

/// A controller that records the payload without any network or storage.
class _RecordingPairingController extends PairingController {
  PairingPayload? received;

  @override
  Future<bool> pair(PairingPayload payload) async {
    received = payload;
    return true;
  }
}

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/pairing',
    routes: [
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingPage(),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const Scaffold(body: Text('feed')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      pairingProvider.overrideWith(() => _RecordingPairingController()),
    ],
    child: testAppWithRouter(router: router),
  );
}

void main() {
  testWidgets('renders manual host and key inputs with connect button', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Sign in with an account instead'), findsOneWidget);
  });

  testWidgets('manual submit builds a payload and navigates on success', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Server address'),
      'http://192.168.1.5:8000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'sk-test-key',
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('invalid manual input shows validation message and stays', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Server address'),
      'not a url',
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid server address and API key'),
      findsOneWidget,
    );
    expect(find.byType(PairingPage), findsOneWidget);
  });

  testWidgets('keyboard types favor URL entry for the host field', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final hostField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Server address'),
    );
    expect(hostField.keyboardType, TextInputType.url);
  });
}
