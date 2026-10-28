/** 全局三刊与发现/收藏模型（v2 Phase E；对齐 /api/v1/site 与 /api/v1/discover）。
 *  手写 fromJson（结构稳定、避免 codegen 面扩大）。 */

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
        episodeId: (json['episodeId'] as num).toInt(),
        podcast: json['podcast'] as String? ?? '',
        originalTitle: json['originalTitle'] as String? ?? '',
        titleZh: json['titleZh'] as String?,
        summaryZh: json['summaryZh'] as String?,
        reasonZh: json['reasonZh'] as String?,
        category: json['category'] as String?,
        categoryLabel: json['categoryLabel'] as String?,
        score: json['score'] as int?,
        url: json['url'] as String?,
        publishedAt: json['publishedAt'] as String?,
        durationSeconds: json['durationSeconds'] as int?,
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
