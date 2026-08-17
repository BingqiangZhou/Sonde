import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_constants.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';

/// Theme mode options
const kThemeModeLight = 'light';
const kThemeModeDark = 'dark';
const kThemeModeSystem = 'system';

/// Theme mode provider
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Selected theme mode code for UI controls.
final themeModeCodeProvider = Provider<String>((ref) {
  ref.watch(themeModeProvider);
  return ref.read(themeModeProvider.notifier).themeModeCode;
});

final initialThemeModeCodeProvider = Provider<String>(
  (ref) => kThemeModeSystem,
);

/// Theme mode notifier for managing app theme
class ThemeModeNotifier extends Notifier<ThemeMode> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  // Internal state: 'light', 'dark', or 'system'
  String _themeModeCode = kThemeModeSystem;

  @override
  ThemeMode build() {
    _themeModeCode = ref.read(initialThemeModeCodeProvider);
    return _getResolvedThemeMode(_themeModeCode);
  }

  /// Get current theme mode code (for UI display)
  String get themeModeCode => _themeModeCode;

  /// Check if using system theme mode
  bool get isSystemThemeMode => _themeModeCode == kThemeModeSystem;

  /// Set and persist theme mode by code
  Future<void> setThemeModeCode(String code) async {
    _themeModeCode = code;
    // Update state with resolved theme mode
    state = _getResolvedThemeMode(code);

    if (code == kThemeModeSystem) {
      await _storage.remove(AppConstants.themeKey);
    } else {
      await _storage.saveString(AppConstants.themeKey, code);
    }
  }

  /// Load saved theme mode from storage
  Future<void> loadSavedThemeMode() async {
    final savedThemeModeCode = await _storage.getString(AppConstants.themeKey);
    _themeModeCode = savedThemeModeCode ?? kThemeModeSystem;
    state = _getResolvedThemeMode(_themeModeCode);
  }

  /// Get resolved theme mode from code
  ThemeMode _getResolvedThemeMode(String code) {
    switch (code) {
      case kThemeModeLight:
        return ThemeMode.light;
      case kThemeModeDark:
        return ThemeMode.dark;
      case kThemeModeSystem:
      default:
        return ThemeMode.system;
    }
  }

  /// Get display name for theme mode
  static String getDisplayName(String code, bool isDark) {
    switch (code) {
      case kThemeModeLight:
        return 'Light';
      case kThemeModeDark:
        return 'Dark';
      case kThemeModeSystem:
      default:
        return 'Follow System';
    }
  }
}
