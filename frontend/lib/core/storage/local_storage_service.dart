import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStorageService {
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);

  Future<void> saveBool(String key, bool value);
  Future<bool?> getBool(String key);

  Future<void> remove(String key);
  Future<void> clear();
  Future<bool> containsKey(String key);

  // App Config
  Future<void> saveApiBaseUrl(String url);
  Future<String?> getApiBaseUrl();

  // Server Config (backend server address)
  Future<void> saveServerBaseUrl(String url);
  Future<String?> getServerBaseUrl();
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden');
});

class LocalStorageServiceImpl implements LocalStorageService {

  LocalStorageServiceImpl(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<void> saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _prefs.containsKey(key);
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    await _prefs.setString('api_base_url', url);
  }

  @override
  Future<String?> getApiBaseUrl() async {
    return _prefs.getString('api_base_url');
  }

  @override
  Future<void> saveServerBaseUrl(String url) async {
    await _prefs.setString('server_base_url', url);
  }

  @override
  Future<String?> getServerBaseUrl() async {
    return _prefs.getString('server_base_url');
  }
}
