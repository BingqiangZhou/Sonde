import 'package:drift/drift.dart';

import 'package:sonde/core/database/app_database.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [SettingsEntries])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(settingsEntries)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return into(settingsEntries).insertOnConflictUpdate(
      SettingsEntriesCompanion.insert(key: key, value: value),
    );
  }

  Future<int> remove(String key) {
    return (delete(settingsEntries)..where((t) => t.key.equals(key))).go();
  }
}
