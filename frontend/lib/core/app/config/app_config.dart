import 'dart:io';

export '../../constants/app_constants.dart' show AppConstants;

class AppConfig {
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // API Configuration
  /// Default server URL (backend address without /api/v1 suffix) derived
  /// purely from build environment and platform. The runtime URL lives in
  /// ServerConfigNotifier (Riverpod state); main() seeds it from storage
  /// via bootstrapServerUrlProvider.
  static String get defaultServerBaseUrl {
    switch (environment) {
      case 'production':
        return 'https://api.personalai.app';
      case 'staging':
        return 'https://api-staging.personalai.app';
      default:
        // Android emulator needs 10.0.2.2 to access host localhost
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:8000';
        }
        return 'http://localhost:8000';
    }
  }

  // Timeouts - Reduced from 300s to 60s for better responsiveness
  static const Duration connectionTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 60);
}

class ApiConstants {
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
