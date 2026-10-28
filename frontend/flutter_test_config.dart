import 'dart:async';

import 'package:sonde/core/utils/app_logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLogger.configure(const AppLoggerConfig.silent());
  try {
    await testMain();
  } finally {
    AppLogger.resetToDefault();
  }
}
