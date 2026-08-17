import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/app/config/app_config.dart';
import 'package:sonde/core/providers/core_providers.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import '../../../helpers/mock_local_storage_service.dart';

void main() {
  group('ServerConfigNotifier Tests', () {
    late MockLocalStorageService mockStorage;

    setUp(() {
      mockStorage = MockLocalStorageService();
    });

    test('should initialize with default server URL', () {
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(mockStorage)],
      );

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, isNotEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);

      container.dispose();
    });

    test('should update server URL successfully', () async {
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(mockStorage)],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      // Use clearData: false to avoid needing other providers
      await notifier.updateServerUrl('http://192.168.1.100:8000', clearData: false);

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, 'http://192.168.1.100:8000');
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);

      container.dispose();
    });

    test('should normalize server URL by removing trailing slashes', () async {
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(mockStorage)],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      // Use clearData: false to avoid needing other providers
      await notifier.updateServerUrl('http://192.168.1.100:8000/', clearData: false);

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, 'http://192.168.1.100:8000');

      container.dispose();
    });

    test('should remove /api/v1 suffix if present', () async {
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(mockStorage)],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      // Test that updateServerUrl removes /api/v1 suffix
      // Use clearData: false to avoid needing other providers
      await notifier.updateServerUrl('http://192.168.1.100:8000/api/v1', clearData: false);

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, 'http://192.168.1.100:8000');

      container.dispose();
    });
  });

  group('AppConfig default URL Tests', () {
    test('defaultServerBaseUrl should return a non-empty URL', () {
      final url = AppConfig.defaultServerBaseUrl;
      expect(url, isNotEmpty);
      expect(url, startsWith('http'));
    });
  });

  group('bootstrapServerUrlProvider Tests', () {
    test('defaults to environment URL when not overridden', () {
      final container = ProviderContainer();

      expect(container.read(bootstrapServerUrlProvider),
          AppConfig.defaultServerBaseUrl);

      container.dispose();
    });

    test('main() override seeds ServerConfigNotifier state', () {
      final container = ProviderContainer(
        overrides: [
          bootstrapServerUrlProvider.overrideWithValue('http://10.0.2.2:8000'),
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
        ],
      );

      expect(
        container.read(serverConfigProvider).serverUrl,
        'http://10.0.2.2:8000',
      );

      container.dispose();
    });
  });
}
