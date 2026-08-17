import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:personal_ai_assistant/core/app/app.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/auth/presentation/providers/onboarding_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kDebugMode) {
        logger.AppLogger.configure(const logger.AppLoggerConfig.debug());
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logger.AppLogger.error(
          '[FlutterError] ${details.exceptionAsString()}',
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logger.AppLogger.error(
          '[PlatformError] $error',
          error: error,
          stackTrace: stack,
        );
        return true;
      };

      final isMobile = Platform.isAndroid || Platform.isIOS;

      // On mobile platforms, AudioService.init() wraps the handler in a
      // foreground service that provides lock-screen controls and a
      // persistent notification. On desktop, we use a plain handler.
      // The resulting handler is fed into Riverpod via a provider override
      // so that the entire app accesses a single instance through
      // [audioHandlerProvider].
      final PodcastAudioHandler platformAudioHandler;
      if (isMobile) {
        platformAudioHandler = await AudioService.init(
          builder: PodcastAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.personal_ai_assistant.audio',
            androidNotificationChannelName: 'Podcast Playback',
            androidNotificationChannelDescription:
                'Podcast audio playback controls',
            androidShowNotificationBadge: true,
            androidStopForegroundOnPause: false,
          ),
        );
        logger.AppLogger.info('AudioService initialized (mobile platform)');
      } else {
        // Desktop platforms do not require media notification integration
        // (AudioService.init provides lock-screen controls and persistent
        // notification on mobile).  A plain handler is sufficient here.
        try {
          platformAudioHandler = PodcastAudioHandler();
          logger.AppLogger.info(
            'PodcastAudioHandler initialized (desktop platform)',
          );
        } catch (e, st) {
          logger.AppLogger.error(
            '[AppInit] Failed to create PodcastAudioHandler on desktop',
            error: e,
            stackTrace: st,
          );
          // Re-throw so the caller knows initialization failed.
          rethrow;
        }
      }

      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        if (!notificationStatus.isGranted) {
          await Permission.notification.request();
        }
      }

      // Desktop platforms allow all orientations (landscape is natural for desktop).
      // Mobile platforms lock to portrait for consistent mobile UX.
      final isDesktop =
          Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      if (isDesktop) {
        await WindowManager.instance.ensureInitialized();
        await WindowManager.instance.setTitle('Stella');
        await WindowManager.instance.setSize(const Size(1280, 720));
        await WindowManager.instance.setMinimumSize(const Size(800, 600));
        // Desktop windows support all orientations natively;
        // no need to call setPreferredOrientations (it is a no-op).
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        // edgeToEdge system UI mode is only relevant for mobile.
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }

      final prefs = await SharedPreferences.getInstance();
      final storageService = LocalStorageServiceImpl(prefs);

      final initialThemeModeCode =
          await storageService.getString(
            AppConstants.themeKey,
          ) ??
          kThemeModeSystem;

      var initialServerUrl = await storageService.getServerBaseUrl() ?? '';
      if (initialServerUrl.isEmpty) {
        // Legacy migration: old API base URL key -> server URL key
        final legacyApiBaseUrl = await storageService.getApiBaseUrl();
        if (legacyApiBaseUrl != null && legacyApiBaseUrl.isNotEmpty) {
          await storageService.saveServerBaseUrl(legacyApiBaseUrl);
          initialServerUrl = legacyApiBaseUrl;
          logger.AppLogger.info(
            '[AppInit] Migrated old API URL to server URL: $legacyApiBaseUrl',
          );
        }
      }
      if (initialServerUrl.isNotEmpty) {
        logger.AppLogger.info('[AppInit] Loaded server URL: $initialServerUrl');
      }

      final hasCompletedOnboarding =
          await storageService.getBool(
            AppConstants.hasCompletedOnboardingKey,
          ) ??
          false;

      runApp(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storageService),
            audioHandlerProvider.overrideWithValue(platformAudioHandler),
            initialThemeModeCodeProvider.overrideWithValue(
              initialThemeModeCode,
            ),
            initialOnboardingCompletedProvider.overrideWithValue(
              hasCompletedOnboarding,
            ),
            if (initialServerUrl.isNotEmpty)
              bootstrapServerUrlProvider.overrideWithValue(initialServerUrl),
          ],
          child: const _AppWithSplashScreen(),
        ),
      );
    },
    (error, stackTrace) {
      logger.AppLogger.error(
        '[ZoneError] $error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class _AppWithSplashScreen extends StatelessWidget {
  const _AppWithSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const PersonalAIAssistantApp();
  }
}
