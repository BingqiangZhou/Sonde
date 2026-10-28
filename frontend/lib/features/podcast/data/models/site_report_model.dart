/** 全局三刊与发现/收藏模型（v2 Phase E；对齐 /api/v1/site 与 /api/v1/discover）。
 *  手写 fromJson（结构稳定、避免 codegen 面扩大）。
 *  Phase G：新增站点 meta / 入选时间线 / 全部动态 / 单集阅读详情模型。 */

class SiteMeta {
  const SiteMeta({
    required this.name,
    required this.nameEn,
    required this.subject,
    this.homeTitle,
    this.description,
    this.tagline,
  });

  factory SiteMeta.fromJson(Map<String, dynamic> json) => SiteMeta(
        name: json['name'] as String? ?? '',
        nameEn: json['nameEn'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        homeTitle: json['homeTitle'] as String?,
        description: json['description'] as String?,
        tagline: json['tagline'] as String?,
      );

  final String name;
  final String nameEn;
  final String subject;
  final String? homeTitle;
  final String? description;
  final String? tagline;
}

class SiteReportItem {
  const SiteReportItem({
    required this.episodeId,
    required this.podcast,
    required this.originalTitle,
    this.titleZh,
    this.summaryZh,
    this.reasonZh,
    this.category,
    this.categoryLabel,
    this.score,
    this.url,
    this.publishedAt,
    this.durationSeconds,
  });

  factory SiteReportItem.fromJson(Map<String, dynamic> json) => SiteReportItem(
        // 报告 sections 内嵌条目带 episodeId；site/episodes 列表用 id（BIGINT 经 JSON 归一为 num/String）
        episodeId: ((json['episodeId'] ?? json['id']) as num?)?.toInt() ?? 0,
        podcast: json['podcast'] as String? ?? '',
        originalTitle: json['originalTitle'] as String? ?? '',
        titleZh: json['titleZh'] as String?,
        summaryZh: json['summaryZh'] as String?,
        reasonZh: json['reasonZh'] as String?,
        category: json['category'] as String?,
        categoryLabel: json['categoryLabel'] as String?,
        score: (json['score'] as num?)?.toInt(),
        url: json['url'] as String?,
        publishedAt: json['publishedAt'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      );

  final int episodeId;
  final String podcast;
  final String originalTitle;
  final String? titleZh;
  final String? summaryZh;
  final String? reasonZh;
  final String? category;
  final String? categoryLabel;
  final int? score;
  final String? url;
  final String? publishedAt;
  final int? durationSeconds;

  String get displayTitle => titleZh?.isNotEmpty == true ? titleZh! : originalTitle;
}

class SiteReportSection {
  const SiteReportSection({required this.section, required this.items});

  factory SiteReportSection.fromJson(Map<String, dynamic> json) =>
      SiteReportSection(
        section: json['section'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SiteReportItem.fromJson)
            .toList(),
      );

  final String section;
  final List<SiteReportItem> items;
}

class SiteReportContent {
  const SiteReportContent({
    required this.title,
    required this.leadParagraph,
    required this.highlights,
    required this.sections,
    required this.selectedCount,
  });

  factory SiteReportContent.fromJson(Map<String, dynamic> json) =>
      SiteReportContent(
        title: json['title'] as String? ?? '',
        leadParagraph: json['leadParagraph'] as String? ?? '',
        highlights:
            (json['highlights'] as List<dynamic>? ?? []).cast<String>(),
        sections: (json['sections'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SiteReportSection.fromJson)
            .toList(),
        selectedCount:
            ((json['stats'] as Map<String, dynamic>?)?['selected'] as num?)
                    ?.toInt() ??
                0,
      );

  final String title;
  final String leadParagraph;
  final List<String> highlights;
  final List<SiteReportSection> sections;
  final int selectedCount;
}

class SiteReport {
  const SiteReport({
    required this.reportKey,
    required this.generatedAt,
    required this.revision,
    required this.content,
  });

  factory SiteReport.fromJson(Map<String, dynamic> json) => SiteReport(
        reportKey: json['reportKey'] as String? ?? '',
        generatedAt: json['generatedAt'] as String?,
        revision: (json['revision'] as num?)?.toInt() ?? 1,
        content: SiteReportContent.fromJson(
            json['content'] as Map<String, dynamic>? ?? {}),
      );

  final String reportKey;
  final String? generatedAt;
  final int revision;
  final SiteReportContent content;
}

class SiteReportKeyEntry {
  const SiteReportKeyEntry(
      {required this.reportKey, required this.generatedAt, this.revision});

  factory SiteReportKeyEntry.fromJson(Map<String, dynamic> json) =>
      SiteReportKeyEntry(
        reportKey: json['reportKey'] as String? ?? '',
        generatedAt: json['generatedAt'] as String?,
        revision: (json['revision'] as num?)?.toInt(),
      );

  final String reportKey;
  final String? generatedAt;
  final int? revision;
}

class SiteReportArchiveResponse {
  const SiteReportArchiveResponse({required this.keys, required this.total});

  factory SiteReportArchiveResponse.fromJson(Map<String, dynamic> json) =>
      SiteReportArchiveResponse(
        keys: (json['keys'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SiteReportKeyEntry.fromJson)
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  final List<SiteReportKeyEntry> keys;
  final int total;
}

/// 报刊种类
enum SiteReportKind { daily, weekly, monthly }

// ── 站点动态（Phase G：/site/episodes*）───────────────────────────────

class SiteSelectedEpisodesResponse {
  const SiteSelectedEpisodesResponse({required this.items});

  factory SiteSelectedEpisodesResponse.fromJson(Map<String, dynamic> json) =>
      SiteSelectedEpisodesResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SiteReportItem.fromJson)
            .toList(),
      );

  final List<SiteReportItem> items;
}

/// 全部动态条目：入选/落选均含，落选带 reason（筛选理由，中文）。
class AnalyzedSiteEpisodeItem {
  const AnalyzedSiteEpisodeItem({
    required this.item,
    required this.selected,
    this.reason,
  });

  factory AnalyzedSiteEpisodeItem.fromJson(Map<String, dynamic> json) =>
      AnalyzedSiteEpisodeItem(
        item: SiteReportItem.fromJson(json),
        selected: json['selected'] as bool? ?? false,
        reason: json['reason'] as String?,
      );

  final SiteReportItem item;
  final bool selected;
  final String? reason;

  String get displayTitle => item.displayTitle;
  String get podcast => item.podcast;
  int? get score => item.score;
}

class SiteAllEpisodesResponse {
  const SiteAllEpisodesResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory SiteAllEpisodesResponse.fromJson(Map<String, dynamic> json) =>
      SiteAllEpisodesResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AnalyzedSiteEpisodeItem.fromJson)
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pages: (json['pages'] as num?)?.toInt() ?? 1,
      );

  final List<AnalyzedSiteEpisodeItem> items;
  final int total;
  final int page;
  final int pages;
}

/// 单集阅读详情（/site/episodes/{id}）：基础条目 + 播放与转录。
class SiteEpisodeDetail {
  const SiteEpisodeDetail({
    required this.item,
    this.audioUrl,
    this.transcript,
    this.tags = const [],
  });

  factory SiteEpisodeDetail.fromJson(Map<String, dynamic> json) =>
      SiteEpisodeDetail(
        item: SiteReportItem.fromJson(json),
        audioUrl: json['audioUrl'] as String?,
        transcript: json['transcript'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      );

  final SiteReportItem item;
  final String? audioUrl;
  final String? transcript;
  final List<String> tags;

  String get displayTitle => item.displayTitle;
}

class SiteEpisodeDetailResponse {
  const SiteEpisodeDetailResponse({required this.episode});

  factory SiteEpisodeDetailResponse.fromJson(Map<String, dynamic> json) =>
      SiteEpisodeDetailResponse(
        episode: SiteEpisodeDetail.fromJson(
            json['episode'] as Map<String, dynamic>? ?? {}),
      );

  final SiteEpisodeDetail episode;
}

// ── 发现（后端代理 iTunes）──────────────────────────────────────────

class DiscoverItem {
  const DiscoverItem({
    required this.collectionId,
    required this.name,
    this.author,
    this.genre,
    this.trackCount,
    this.artworkUrl,
    this.feedUrl,
    this.appleUrl,
    this.rank,
    this.stores = const [],
    this.subscribed = false,
  });

  factory DiscoverItem.fromJson(Map<String, dynamic> json) => DiscoverItem(
        collectionId: (json['collectionId'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        author: json['author'] as String?,
        genre: json['genre'] as String?,
        trackCount: (json['trackCount'] as num?)?.toInt(),
        artworkUrl: json['artworkUrl'] as String?,
        feedUrl: json['feedUrl'] as String?,
        appleUrl: json['appleUrl'] as String?,
        rank: (json['rank'] as num?)?.toInt(),
        stores: (json['stores'] as List<dynamic>? ?? []).cast<String>(),
        subscribed: json['subscribed'] as bool? ?? false,
      );

  final int collectionId;
  final String name;
  final String? author;
  final String? genre;
  final int? trackCount;
  final String? artworkUrl;
  final String? feedUrl;
  final String? appleUrl;
  final int? rank;
  final List<String> stores;
  final bool subscribed;
}

class DiscoverSearchResponse {
  const DiscoverSearchResponse(
      {required this.countries, required this.total, required this.results});

  factory DiscoverSearchResponse.fromJson(Map<String, dynamic> json) =>
      DiscoverSearchResponse(
        countries: (json['countries'] as List<dynamic>? ?? []).cast<String>(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        results: (json['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DiscoverItem.fromJson)
            .toList(),
      );

  final List<String> countries;
  final int total;
  final List<DiscoverItem> results;
}

class DiscoverChartsResponse {
  const DiscoverChartsResponse(
      {required this.country, required this.total, required this.results});

  factory DiscoverChartsResponse.fromJson(Map<String, dynamic> json) =>
      DiscoverChartsResponse(
        country: json['country'] as String? ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        results: (json['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DiscoverItem.fromJson)
            .toList(),
      );

  final String country;
  final int total;
  final List<DiscoverItem> results;
}

// ── 收藏（per-user 云同步）─────────────────────────────────────────

class FavoriteEpisode {
  const FavoriteEpisode({
    required this.id,
    required this.subscriptionId,
    required this.subscriptionTitle,
    required this.title,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    this.publishedAt,
    this.aiSummary,
    this.favoritedAt,
  });

  factory FavoriteEpisode.fromJson(Map<String, dynamic> json) =>
      FavoriteEpisode(
        id: (json['id'] as num).toInt(),
        subscriptionId: (json['subscription_id'] as num?)?.toInt() ?? 0,
        subscriptionTitle: json['subscription_title'] as String?,
        title: json['title'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        audioUrl: json['audio_url'] as String?,
        audioDuration: (json['audio_duration'] as num?)?.toInt(),
        publishedAt: json['published_at'] as String?,
        aiSummary: json['ai_summary'] as String?,
        favoritedAt: json['favorited_at'] as String?,
      );

  final int id;
  final int subscriptionId;
  final String? subscriptionTitle;
  final String title;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;
  final String? publishedAt;
  final String? aiSummary;
  final String? favoritedAt;
}

class FavoritesListResponse {
  const FavoritesListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory FavoritesListResponse.fromJson(Map<String, dynamic> json) =>
      FavoritesListResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(FavoriteEpisode.fromJson)
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pages: (json['pages'] as num?)?.toInt() ?? 1,
      );

  final List<FavoriteEpisode> items;
  final int total;
  final int page;
  final int pages;
}

class FavoriteStatusResponse {
  const FavoriteStatusResponse(
      {required this.episodeId, required this.favorited});

  factory FavoriteStatusResponse.fromJson(Map<String, dynamic> json) =>
      FavoriteStatusResponse(
        episodeId: (json['episode_id'] as num?)?.toInt() ?? 0,
        favorited: json['favorited'] as bool? ?? false,
      );

  final int episodeId;
  final bool favorited;
}
