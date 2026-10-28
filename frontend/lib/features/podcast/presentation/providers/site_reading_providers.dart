/** 阅读域 providers（v2 Phase G）：站点 meta / 全部动态分页 / 指定期刊物。 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

/// 站点身份（站名/标语；失败时静默为 null，页面用品牌兜底文案）
final siteMetaProvider = FutureProvider.autoDispose<SiteMeta?>((ref) async {
  try {
    return await ref.read(podcastRepositoryProvider).getSiteMeta();
  } catch (_) {
    return null;
  }
});

/// 全部动态（含落选条目）分页状态
class SiteAllEpisodesState {
  const SiteAllEpisodesState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.pages = 0,
    this.isLoading = false,
    this.hasError = false,
  });

  final List<AnalyzedSiteEpisodeItem> items;
  final int total;
  final int page;
  final int pages;
  final bool isLoading;
  final bool hasError;

  bool get hasMore => page < pages;

  SiteAllEpisodesState copyWith({
    List<AnalyzedSiteEpisodeItem>? items,
    int? total,
    int? page,
    int? pages,
    bool? isLoading,
    bool? hasError,
  }) =>
      SiteAllEpisodesState(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
      );
}

const int _pageSize = 50;

class SiteAllEpisodesNotifier extends AsyncNotifier<SiteAllEpisodesState> {
  @override
  Future<SiteAllEpisodesState> build() async {
    final response =
        await ref.read(podcastRepositoryProvider).getSiteAllEpisodes(
              size: _pageSize,
            );
    return SiteAllEpisodesState(
      items: response.items,
      total: response.total,
      page: response.page,
      pages: response.pages,
    );
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null || current.isLoading || !current.hasMore) {
      return;
    }
    state = AsyncValue.data(current.copyWith(isLoading: true));
    try {
      final response = await ref
          .read(podcastRepositoryProvider)
          .getSiteAllEpisodes(page: current.page + 1, size: _pageSize);
      state = AsyncValue.data(current.copyWith(
        items: [...current.items, ...response.items],
        page: response.page,
        pages: response.pages,
        isLoading: false,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoading: false, hasError: true));
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final siteAllEpisodesProvider =
    AsyncNotifierProvider<SiteAllEpisodesNotifier, SiteAllEpisodesState>(
        SiteAllEpisodesNotifier.new);

/// 指定期刊物（归档详情用；按 kind+key 族，autoDispose 避免占内存）
final siteReportIssueProvider = FutureProvider.autoDispose
    .family<SiteReport?, (SiteReportKind, String)>((ref, key) async {
  try {
    return await ref.read(podcastRepositoryProvider).getSiteReport(
          key.$1.name,
          reportKey: key.$2,
        );
  } catch (_) {
    return null;
  }
});
