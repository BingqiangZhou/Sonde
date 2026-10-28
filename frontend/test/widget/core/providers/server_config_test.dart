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
      // Reset AppConfig
      AppConfig.setServerBaseUrl('');
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

  group('AppConfig Tests', () {
    setUp(() {
      AppConfig.setServerBaseUrl('');
    });

    test('serverBaseUrl should return default URL when not set', () {
      final url = AppConfig.serverBaseUrl;
      expect(url, isNotEmpty);
      expect(url.contains('localhost'), isTrue);
    });

    test('setServerBaseUrl should update the URL', () {
      AppConfig.setServerBaseUrl('http://example.com');
      expect(AppConfig.serverBaseUrl, 'http://example.com');
    });

    test('apiBaseUrl should return same as serverBaseUrl', () {
      AppConfig.setServerBaseUrl('http://test.com');
      expect(AppConfig.apiBaseUrl, 'http://test.com');
    });

    test('setApiBaseUrl should work for backward compatibility', () {
      AppConfig.setApiBaseUrl('http://compat.com');
      expect(AppConfig.serverBaseUrl, 'http://compat.com');
    });
  });
}
