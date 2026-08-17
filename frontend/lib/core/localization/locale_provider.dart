import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/constants/app_constants.dart';
import 'package:sonde/core/storage/local_storage_service.dart';

/// Supported language codes
const kLanguageEnglish = 'en';
const kLanguageChinese = 'zh';
const kLanguageSystem = 'system';

/// Locale provider
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Selected language code for UI controls.
final localeCodeProvider = Provider<String>((ref) {
  ref.watch(localeProvider);
  return ref.read(localeProvider.notifier).languageCode;
});

/// Locale notifier for managing app language
class LocaleNotifier extends Notifier<Locale> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  // Internal state: 'en', 'zh', or 'system'
  String _languageCode = kLanguageSystem;

  @override
  Locale build() {
    return _getResolvedLocale(_languageCode);
  }

  /// Get current language code (for UI display)
  String get languageCode => _languageCode;

  /// Check if using system locale
  bool get isSystemLocale => _languageCode == kLanguageSystem;

  /// Set and persist locale by language code
  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    // Update state with resolved locale
    state = _getResolvedLocale(code);

    if (code == kLanguageSystem) {
      await _storage.remove(AppConstants.localeKey);
    } else {
      await _storage.saveString(AppConstants.localeKey, code);
    }
  }

  /// Load saved locale from storage
  Future<void> loadSavedLocale() async {
    final savedLanguageCode = await _storage.getString(AppConstants.localeKey);
    _languageCode = savedLanguageCode ?? kLanguageSystem;
    state = _getResolvedLocale(_languageCode);
  }

  /// Get resolved locale from language code
  Locale _getResolvedLocale(String code) {
    if (code == kLanguageSystem) {
      return _getSystemLocale();
    }
    return Locale(code);
  }

  /// Get system locale (defaults to English if not supported)
  static Locale _getSystemLocale() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final languageCode = systemLocale.languageCode;

    // If system language is Chinese, use Chinese
    if (languageCode == 'zh') {
      return const Locale(kLanguageChinese);
    }
    // Default to English
    return const Locale(kLanguageEnglish);
  }
}
