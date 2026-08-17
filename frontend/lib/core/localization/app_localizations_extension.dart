import 'package:flutter/widgets.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_en.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this) ?? AppLocalizationsEn();
}
