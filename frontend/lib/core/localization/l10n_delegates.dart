import 'package:cupertino_ui/cupertino_ui.dart' as cupertino_ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart' as material_ui;

import 'package:sonde/core/localization/app_localizations.dart';

/// 应用侧 l10n delegates 列表。
///
/// gen-l10n 生成的 [AppLocalizations.localizationsDelegates] 引用的是
/// flutter_localizations 旧版 Global*；Flutter 解耦迁移后 material_ui /
/// cupertino_ui 组件查找的是新包版本，因此在此维护列表，生成文件保持
/// 原样、可随时重新生成。待 gen-l10n 支持新包后可回退到生成的 getter。
const List<LocalizationsDelegate<Object>> appLocalizationsDelegates =
    <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      material_ui.GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      cupertino_ui.GlobalCupertinoLocalizations.delegate,
    ];
