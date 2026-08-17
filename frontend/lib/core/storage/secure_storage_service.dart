import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:personal_ai_assistant/core/app/config/app_config.dart' as config;
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

abstract class SecureStorageService {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();

  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();

  Future<void> saveUserId(String userId);
  Future<String?> getUserId();

  Future<void> saveTokenExpiry(DateTime expiry);
  Future<DateTime?> getTokenExpiry();
  Future<void> clearTokenExpiry();

  Future<void> clearTokens();
  Future<void> clearAll();

  Future<void> save(String key, String value);
  Future<String?> get(String key);
  Future<void> remove(String key);
  Future<bool> containsKey(String key);
}

class SecureStorageServiceImpl implements SecureStorageService {

  SecureStorageServiceImpl(this._secureStorage);
  final FlutterSecureStorage _secureStorage;

  static const String _accessTokenKey = config.AppConstants.accessTokenKey;
  static const String _refreshTokenKey = config.AppConstants.refreshTokenKey;
  static const String _userIdKey = 'user_id';
  static const String _tokenExpiryKey = config.AppConstants.tokenExpiryKey;

  Future<void> _safeWrite({required String key, required String? value}) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[SecureStorage] write($key) failed: ${e.message}');
    }
  }

  Future<String?> _safeRead({required String key}) async {
    try {
      return await _secureStorage.read(key: key);
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[SecureStorage] read($key) failed: ${e.message}');
      return null;
    }
  }

  Future<void> _safeDelete({required String key}) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[SecureStorage] delete($key) failed: ${e.message}');
    }
  }

  @override
  Future<void> saveAccessToken(String token) async {
    await _safeWrite(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return _safeRead(key: _accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _safeWrite(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _safeRead(key: _refreshTokenKey);
  }

  @override
  Future<void> saveUserId(String userId) async {
    await _safeWrite(key: _userIdKey, value: userId);
  }

  @override
  Future<String?> getUserId() async {
    return _safeRead(key: _userIdKey);
  }

  @override
  Future<void> saveTokenExpiry(DateTime expiry) async {
    await _safeWrite(key: _tokenExpiryKey, value: expiry.toIso8601String());
  }

  @override
  Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _safeRead(key: _tokenExpiryKey);
    if (expiryString != null) {
      return DateTime.tryParse(expiryString);
    }
    return null;
  }

  @override
  Future<void> clearTokenExpiry() async {
    await _safeDelete(key: _tokenExpiryKey);
  }

  @override
  Future<void> clearTokens() async {
    await _safeDelete(key: _accessTokenKey);
    await _safeDelete(key: _refreshTokenKey);
    await _safeDelete(key: _userIdKey);
    await _safeDelete(key: _tokenExpiryKey);
  }

  @override
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[SecureStorage] deleteAll failed: ${e.message}');
    }
  }

  @override
  Future<void> save(String key, String value) async {
    await _safeWrite(key: key, value: value);
  }

  @override
  Future<String?> get(String key) async {
    return _safeRead(key: key);
  }

  @override
  Future<void> remove(String key) async {
    await _safeDelete(key: key);
  }

  @override
  Future<bool> containsKey(String key) async {
    final value = await _safeRead(key: key);
    return value != null;
  }
}
