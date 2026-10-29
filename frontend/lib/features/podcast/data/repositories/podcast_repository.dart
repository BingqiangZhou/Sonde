import 'package:dio/dio.dart';
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_summary_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:sonde/features/podcast/data/models/profile_stats_model.dart';
import 'package:sonde/features/podcast/data/models/schedule_config_model.dart';
import 'package:sonde/features/podcast/data/services/podcast_api_service.dart';

class PodcastRepository {

  PodcastRepository(this._apiService);
  final PodcastApiService _apiService;


  /// Generic wrapper that converts [DioException] to [NetworkException].
  ///
  /// Eliminates the repetitive try/catch pattern across all API methods.
  Future<T> _apiCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw NetworkException.fromDioError(e);
    }
  }

  // === Subscription Management ===

  Future<PodcastSubscriptionModel> addSubscription({
    required String feedUrl,
    List<int>? categoryIds,
  }) =>
      _apiCall(() => _apiService.addSubscription(
            PodcastSubscriptionCreateRequest(
              feedUrl: feedUrl,
              categoryIds: categoryIds,
            ),
          ));

  Future<PodcastSubscriptionListResponse> listSubscriptions({
    int page = 1,
    int size = 20,
    int? categoryId,
    String? status,
  }) =>
      _apiCall(() => _apiService.listSubscriptions(page, size, categoryId, status));

  Future<PodcastSubscriptionModel> getSubscription(int subscriptionId) =>
      _apiCall(() => _apiService.getSubscription(subscriptionId));

  Future<void> deleteSubscription(int subscriptionId) =>
      _apiCall(() => _apiService.deleteSubscription(subscriptionId));

  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions({
    required List<int> subscriptionIds,
  }) =>
      _apiCall(() => _apiService.bulkDeleteSubscriptions(
            PodcastSubscriptionBulkDeleteRequest(
              subscriptionIds: subscriptionIds,
            ),
          ));

  Future<void> refreshSubscription(int subscriptionId) =>
      _apiCall(() => _apiService.refreshSubscription(subscriptionId));

  Future<ReparseResponse> reparseSubscription(
    int subscriptionId,
    bool forceAll,
  ) =>
      _apiCall(() => _apiService.reparseSubscription(subscriptionId, forceAll));

  // === Episode Management ===

  Future<PodcastFeedResponse> getPodcastFeed({
    required int page,
    required int pageSize,
    String? cursor,
  }) =>
      _apiCall(() => _apiService.getPodcastFeed(page, pageSize, cursor));

  /// 三刊（v2 全局报刊）：最新一期 / 指定期 / 归档
  Future<SiteReport> getSiteReport(String kind, {String? reportKey}) =>
      _apiCall(() => reportKey == null
          ? _apiService.getLatestSiteReport(kind)
          : _apiService.getSiteReport(kind, reportKey));

  Future<SiteReportArchiveResponse> getSiteReportArchive(String kind,
          {int page = 1, int size = 30}) =>
      _apiCall(() => _apiService.getSiteReportArchive(kind,
          page: page, size: size));

  /// 站点动态（Phase G）：meta / 入选时间线 / 全部动态分页 / 单集阅读详情
  Future<SiteMeta> getSiteMeta() => _apiCall(() => _apiService.getSiteMeta());

  Future<SiteSelectedEpisodesResponse> getSiteSelectedEpisodes({
    int limit = 20,
  }) =>
      _apiCall(() => _apiService.getSiteSelectedEpisodes(limit: limit));

  Future<SiteAllEpisodesResponse> getSiteAllEpisodes({
    int page = 1,
    int size = 50,
  }) =>
      _apiCall(() => _apiService.getSiteAllEpisodes(page: page, size: size));

  Future<SiteEpisodeDetail> getSiteEpisodeDetail(int episodeId) async =>
      (await _apiCall(() => _apiService.getSiteEpisodeDetail(episodeId)))
          .episode;

  /// 发现（后端代理 iTunes）
  Future<DiscoverSearchResponse> discoverSearch(String query, {int? limit}) =>
      _apiCall(() => _apiService.discoverSearch(query, limit: limit));

  Future<DiscoverChartsResponse> discoverCharts(String country, {int? limit}) =>
      _apiCall(() => _apiService.discoverCharts(country, limit: limit));

  /// 收藏同步
  Future<FavoritesListResponse> listFavorites({int page = 1, int size = 50}) =>
      _apiCall(
          () => _apiService.listFavorites(page: page, size: size));

  Future<bool> isFavorite(int episodeId) async {
    try {
      final status = await _apiCall(() => _apiService.getFavoriteStatus(episodeId));
      return status.favorited;
    } on NetworkException {
      return false;
    }
  }

  Future<void> addFavorite(int episodeId) =>
      _apiCall(() => _apiService.addFavorite(episodeId));

  Future<void> removeFavorite(int episodeId) =>
      _apiCall(() => _apiService.removeFavorite(episodeId));

  Future<PodcastEpisodeListResponse> listEpisodes({
    int? subscriptionId,
    int page = 1,
    int size = 20,
    bool? hasSummary,
  }) =>
      _apiCall(() => _apiService.listEpisodes(
            subscriptionId,
            page,
            size,
            hasSummary,
          ));

  Future<PodcastEpisodeModel> getEpisode(int episodeId) =>
      _apiCall(() => _apiService.getEpisode(episodeId));

  // === Summary Management ===

  Future<PodcastSummaryStartResponse> generateSummary({
    required int episodeId,
    bool forceRegenerate = false,
    bool? useTranscript,
    String? summaryModel,
    String? customPrompt,
  }) =>
      _apiCall(() => _apiService.generateSummary(
            episodeId,
            PodcastSummaryRequest(
              forceRegenerate: forceRegenerate,
              useTranscript: useTranscript,
              summaryModel: summaryModel,
              customPrompt: customPrompt,
            ),
          ));

  Future<List<SummaryModelInfo>> getSummaryModels() =>
      _apiCall(() async => (await _apiService.getSummaryModels()).models);

  Future<void> getPendingSummaries() =>
      _apiCall(_apiService.getPendingSummaries);

  // === Search ===

  Future<PodcastEpisodeListResponse> searchPodcasts({
    required String query,
    String searchIn = 'all',
    int page = 1,
    int size = 20,
  }) =>
      _apiCall(() => _apiService.searchPodcasts(query, searchIn, page, size));

  // === Statistics ===

  Future<ProfileStatsModel> getProfileStats() =>
      _apiCall(_apiService.getProfileStats);

  // === Transcription Management ===

  Future<PodcastTranscriptionResponse?> getTranscription(int episodeId) async {
    try {
      return await _apiService.getTranscription(episodeId);
    } on DioException catch (e) {
      // If transcription not found (404), return null instead of throwing
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw NetworkException.fromDioError(e);
    }
  }

  Future<PodcastTranscriptionResponse> startTranscription(
    int episodeId, {
    bool forceRegenerate = false,
    int? chunkSizeMb,
    String? transcriptionModel,
  }) =>
      _apiCall(() => _apiService.startTranscription(
            episodeId,
            PodcastTranscriptionRequest(
              forceRegenerate: forceRegenerate,
              chunkSizeMb: chunkSizeMb,
              transcriptionModel: transcriptionModel,
            ),
          ));

  Future<void> deleteTranscription(int episodeId) =>
      _apiCall(() => _apiService.deleteTranscription(episodeId));

  // === Conversation Management ===

  Future<ConversationSessionListResponse> getConversationSessions({
    required int episodeId,
  }) =>
      _apiCall(() => _apiService.getConversationSessions(episodeId));

  Future<ConversationSession> createConversationSession({
    required int episodeId,
    String? title,
  }) =>
      _apiCall(() => _apiService.createConversationSession(episodeId, {
            'title': title,
          }));

  Future<PodcastConversationClearResponse> deleteConversationSession({
    required int episodeId,
    required int sessionId,
  }) =>
      _apiCall(() => _apiService.deleteConversationSession(episodeId, sessionId));

  Future<PodcastConversationHistoryResponse> getConversationHistory({
    required int episodeId,
    int limit = 50,
    int? sessionId,
  }) =>
      _apiCall(() => _apiService.getConversationHistory(episodeId, limit, sessionId));

  Future<PodcastConversationSendResponse> sendConversationMessage({
    required int episodeId,
    required PodcastConversationSendRequest request,
  }) =>
      _apiCall(() => _apiService.sendConversationMessage(episodeId, request));

  Future<PodcastConversationClearResponse> clearConversationHistory({
    required int episodeId,
    int? sessionId,
  }) =>
      _apiCall(() => _apiService.clearConversationHistory(episodeId, sessionId));

  // === Schedule Management ===

  Future<ScheduleConfigResponse> getSubscriptionSchedule(
    int subscriptionId,
  ) =>
      _apiCall(() => _apiService.getSubscriptionSchedule(subscriptionId));

  Future<ScheduleConfigResponse> updateSubscriptionSchedule(
    int subscriptionId,
    ScheduleConfigUpdateRequest request,
  ) =>
      _apiCall(() => _apiService.updateSubscriptionSchedule(subscriptionId, request));

  /// Get all subscription schedules
  Future<List<ScheduleConfigResponse>> getAllSubscriptionSchedules() =>
      _apiCall(_apiService.getAllSubscriptionSchedules);

  /// Batch update subscription schedules
  Future<List<ScheduleConfigResponse>> batchUpdateSubscriptionSchedules(
    List<int> subscriptionIds,
    ScheduleConfigUpdateRequest request,
  ) =>
      _apiCall(() => _apiService.batchUpdateSubscriptionSchedules({
            'subscription_ids': subscriptionIds,
            'schedule_data': request.toJson(),
          }));

  // === Highlights Management ===

  Future<HighlightsListResponse> getHighlights({
    DateTime? date,
    int page = 1,
    int perPage = 20,
    int? episodeId,
  }) =>
      _apiCall(() => _apiService.getHighlights(
            date != null ? TimeFormatter.formatDate(date) : null,
            page,
            perPage,
            episodeId,
          ));

  Future<HighlightDatesResponse> getHighlightDates() =>
      _apiCall(_apiService.getHighlightDates);

  Future<HighlightStatsResponse> getHighlightStats() =>
      _apiCall(_apiService.getHighlightStats);

  Future<void> toggleHighlightFavorite(int highlightId) =>
      _apiCall(() => _apiService.toggleHighlightFavorite(highlightId));

  Future<void> deleteHighlight(int highlightId) =>
      _apiCall(() => _apiService.deleteHighlight(highlightId));

  Future<HighlightExtractResponse> extractEpisodeHighlights(int episodeId) =>
      _apiCall(() => _apiService.extractEpisodeHighlights(episodeId));
}
