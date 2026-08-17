import 'dart:async';

import 'package:sonde/core/utils/app_logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const silentConfig = AppLoggerConfig(
    debugEnabled: false,
    infoEnabled: false,
    warningEnabled: false,
    errorEnabled: false,
  );
  AppLogger.configure(silentConfig);
  try {
    await testMain();
  } finally {
    AppLogger.configure(const AppLoggerConfig.production());
  }
}
