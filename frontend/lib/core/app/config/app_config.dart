import 'dart:io';

export '../../constants/app_constants.dart' show AppConstants;

class AppConfig {
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  // API Configuration
  // Server Base URL (backend server address without /api/v1 suffix)
  static String _serverBaseUrl = '';

  static String get serverBaseUrl {
    if (_serverBaseUrl.isNotEmpty) {
      return _serverBaseUrl;
    }

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

  // API Base URL (for backward compatibility, uses serverBaseUrl)
  static String get apiBaseUrl => serverBaseUrl;

  static void setServerBaseUrl(String url) {
    _serverBaseUrl = url;
  }

  // For backward compatibility
  static void setApiBaseUrl(String url) {
    setServerBaseUrl(url);
  }

  // App Configuration
  static const String appName = 'Personal AI Assistant';

  // Timeouts - Reduced from 300s to 60s for better responsiveness
  static const Duration connectionTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 60);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}

class ApiConstants {
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // API Endpoints
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/me';

  static const String assistant = '/assistant';
  static const String chat = '/assistant/chat';
  static const String conversations = '/assistant/conversations';

  static const String podcast = '/podcast';
  static const String feeds = '/podcast/feeds';
  static const String episodes = '/podcast/episodes';

  static const String subscription = '/subscription';
  static const String feedsSubscriptions = '/subscription/feeds';
}
