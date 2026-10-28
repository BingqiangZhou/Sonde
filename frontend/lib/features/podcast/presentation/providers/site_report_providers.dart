/** 全局三刊 providers（v2 Phase E：/api/v1/site/reports，按 kind 分族）。 */

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/data/models/site_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

final selectedReportKindProvider =
    NotifierProvider<SelectedReportKindNotifier, SiteReportKind>(
  SelectedReportKindNotifier.new,
);

class SelectedReportKindNotifier extends Notifier<SiteReportKind> {
  @override
  SiteReportKind build() => SiteReportKind.daily;

  void set(SiteReportKind value) {
    state = value;
  }
}

String kindKey(SiteReportKind kind) => kind.name;

/// 最新一期刊物（按 kind 分族）
final siteReportProvider = AsyncNotifierProvider.autoDispose
    .family<SiteReportNotifier, SiteReport?, SiteReportKind>(
        SiteReportNotifier.new);

class SiteReportNotifier extends AsyncNotifier<SiteReport?> {
  SiteReportNotifier(this.kind);

  final SiteReportKind kind;

  @override
  FutureOr<SiteReport?> build() async {
    try {
      final repo = ref.read(podcastRepositoryProvider);
      return await repo.getSiteReport(kindKey(kind));
    } catch (error) {
      logger.AppLogger.debug('Failed to load ${kind.name} report: $error');
      return null;
    }
  }

  Future<void> loadKey(String reportKey) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(podcastRepositoryProvider);
      state = AsyncValue.data(await repo.getSiteReport(
        kindKey(kind),
        reportKey: reportKey,
      ));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => await build());
  }
}

/// 归档 key 列表（按 kind 分族）
final siteReportArchiveProvider = AsyncNotifierProvider.autoDispose
    .family<SiteReportArchiveNotifier, SiteReportArchiveResponse?,
        SiteReportKind>(SiteReportArchiveNotifier.new);

class SiteReportArchiveNotifier
    extends AsyncNotifier<SiteReportArchiveResponse?> {
  SiteReportArchiveNotifier(this.kind);

  final SiteReportKind kind;

  @override
  FutureOr<SiteReportArchiveResponse?> build() async {
    try {
      final repo = ref.read(podcastRepositoryProvider);
      return await repo.getSiteReportArchive(kindKey(kind), size: 90);
    } catch (error) {
      logger.AppLogger.debug('Failed to load ${kind.name} archive: $error');
      return null;
    }
  }
}
