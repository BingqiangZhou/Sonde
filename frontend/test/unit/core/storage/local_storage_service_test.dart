import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalStorageServiceImpl cacheData/getCachedData', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('stores and reads cache by the same key', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = LocalStorageServiceImpl(prefs);

      await service.cacheData('a', <String, dynamic>{'v': 1});
      final value = await service.getCachedData<Map<String, dynamic>>('a');

      expect(value, isNotNull);
      expect(value?['v'], 1);
    });

    test('returns null after expiration', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = LocalStorageServiceImpl(prefs);

      await service.cacheData('a', <String, dynamic>{
        'v': 1,
      }, expiration: const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 25));

      final value = await service.getCachedData<Map<String, dynamic>>('a');
      expect(value, isNull);
    });

    test('does not mix expiration across different keys', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = LocalStorageServiceImpl(prefs);

      await service.cacheData('a', <String, dynamic>{
        'v': 1,
      }, expiration: const Duration(milliseconds: 10));
      await service.cacheData('b', <String, dynamic>{
        'v': 2,
      }, expiration: const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 25));

      final a = await service.getCachedData<Map<String, dynamic>>('a');
      final b = await service.getCachedData<Map<String, dynamic>>('b');

      expect(a, isNull);
      expect(b, isNotNull);
      expect(b?['v'], 2);
    });
  });
}
