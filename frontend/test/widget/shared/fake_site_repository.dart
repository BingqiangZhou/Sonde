/** 站点阅读域测试桩（Phase G）：Fake PodcastRepository + 固定刊物/动态数据。 */

import 'package:dio/dio.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/data/repositories/podcast_repository.dart';
import 'package:sonde/features/podcast/data/services/podcast_api_service.dart';

SiteReportItem _item({
  required int id,
  required String originalTitle,
  String? titleZh,
  String? summaryZh,
  int? score,
  String? categoryLabel,
  String? url,
}) =>
    SiteReportItem(
      episodeId: id,
      podcast: '播客-$id',
      originalTitle: originalTitle,
      titleZh: titleZh,
      summaryZh: summaryZh,
      score: score,
      categoryLabel: categoryLabel,
      durationSeconds: 1800,
    );

class FakeSiteRepository extends PodcastRepository {
  FakeSiteRepository() : super(PodcastApiService(Dio()));

  /// 请求记录（kind:latest / kind:key），供断言
  final List<String> requests = [];

  SiteReport _report(String kind, String reportKey) => SiteReport(
        reportKey: reportKey,
        generatedAt: '2026-10-27T08:00:00',
        revision: 2,
        content: SiteReportContent(
          title: '$kind 刊头标题',
          leadParagraph: '$kind 导语内容',
          highlights: ['看点一', '看点二'],
          sections: [
            SiteReportSection(
              section: '科技与 AI',
              items: [
                _item(
                  id: 1,
                  originalTitle: 'Original Title 1',
                  titleZh: '入选中文标题',
                  summaryZh: '中文摘要内容',
                  score: 90,
                  categoryLabel: '科技与 AI',
                ),
              ],
            ),
          ],
          selectedCount: 1,
        ),
      );

  @override
  Future<SiteReport> getSiteReport(String kind, {String? reportKey}) async {
    requests.add(reportKey == null ? '$kind:latest' : '$kind:$reportKey');
    return _report(kind, reportKey ?? '2026-10-27');
  }

  @override
  Future<SiteReportArchiveResponse> getSiteReportArchive(
    String kind, {
    int page = 1,
    int size = 30,
  }) async =>
      SiteReportArchiveResponse(
        keys: [
          SiteReportKeyEntry(
            reportKey: '2026-10-27',
            generatedAt: '2026-10-27T08:00:00',
            revision: 2,
          ),
          SiteReportKeyEntry(
            reportKey: '2026-10-26',
            generatedAt: '2026-10-26T08:00:00',
            revision: 1,
          ),
        ],
        total: 2,
      );

  @override
  Future<SiteMeta> getSiteMeta() async => const SiteMeta(
        name: '声读',
        nameEn: 'Sonde',
        subject: '播客',
        tagline: '把一天的播客，读成一份日报',
      );

  static const selectedEntry = AnalyzedSiteEpisodeItem(
    selected: true,
    item: SiteReportItem(
      episodeId: 1,
      podcast: '播客-1',
      originalTitle: 'Original Title 1',
      titleZh: '入选中文标题',
      summaryZh: '中文摘要内容',
      score: 90,
      categoryLabel: '科技与 AI',
      durationSeconds: 1800,
    ),
  );

  static const unselectedEntry = AnalyzedSiteEpisodeItem(
    selected: false,
    reason: '信息量低',
    item: SiteReportItem(
      episodeId: 2,
      podcast: '播客-2',
      originalTitle: 'Unselected Original Title',
      score: 40,
      url: 'https://example.com/episode-2',
      durationSeconds: 600,
    ),
  );

  static const page2Entry = AnalyzedSiteEpisodeItem(
    selected: true,
    item: SiteReportItem(
      episodeId: 3,
      podcast: '播客-3',
      originalTitle: 'Page 2 Title',
      titleZh: '第二页中文标题',
      score: 75,
      durationSeconds: 2400,
    ),
  );

  @override
  Future<SiteAllEpisodesResponse> getSiteAllEpisodes({
    int page = 1,
    int size = 50,
  }) async {
    const pages = {
      1: [selectedEntry, unselectedEntry],
      2: [page2Entry],
    };
    return SiteAllEpisodesResponse(
      items: pages[page] ?? const [],
      total: 3,
      page: page,
      pages: 2,
    );
  }

  @override
  Future<SiteEpisodeDetail> getSiteEpisodeDetail(int episodeId) async =>
      SiteEpisodeDetail(
        item: _item(id: episodeId, originalTitle: 'Original $episodeId'),
        audioUrl: 'https://example.com/audio.mp3',
        transcript: '转录内容',
        tags: const ['AI'],
      );
}
