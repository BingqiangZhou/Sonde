import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/app/app.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/settings/presentation/providers/app_update_provider.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();

  @override
  Future<void> checkAuthStatus() async {}
}

class _MemoryLocalStorageService implements LocalStorageService {
  final Map<String, Object?> _storage = <String, Object?>{};

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<String?> getApiBaseUrl() async => _storage['api_base_url'] as String?;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    _storage['api_base_url'] = url;
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    _storage[key] = value;
  }

  @override
  Future<void> saveServerBaseUrl(String url) async {
    _storage['server_base_url'] = url;
  }

  @override
  Future<void> saveString(String key, String value) async {
    _storage[key] = value;
  }
}

void main() {
  testWidgets('app init splash renders without GlassPanel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          localStorageServiceProvider.overrideWithValue(
            _MemoryLocalStorageService(),
          ),
          autoUpdateCheckProvider.overrideWith(
            (ref) async => const AppUpdateState(),
          ),
        ],
        child: const PersonalAIAssistantApp(),
      ),
    );

    expect(find.text('Sonde'), findsOneWidget);
    expect(
      find.text('Your personal assistant for everything you follow.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app_init_logo')), findsOneWidget);
    expect(find.byKey(const Key('app_init_loading_indicator')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SurfacePanel), findsNothing);
    expect(
      find.ancestor(
        of: find.byKey(const Key('app_init_logo')),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
            return false;
          }

          final decoration = widget.decoration as BoxDecoration;
          return decoration.gradient != null || decoration.color != null;
        }),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
