import 'package:dio/dio.dart';
import 'package:sonde/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_summary_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:sonde/features/podcast/data/models/profile_stats_model.dart';
import 'package:sonde/features/podcast/data/models/schedule_config_model.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:retrofit/retrofit.dart';

part 'podcast_api_service.g.dart';

@RestApi()
abstract class PodcastApiService {
  factory PodcastApiService(Dio dio, {String baseUrl}) = _PodcastApiService;

  // === Subscription Management ===

  @POST('/podcasts/subscriptions')
  Future<PodcastSubscriptionModel> addSubscription(
    @Body() PodcastSubscriptionCreateRequest request,
  );

  @GET('/podcasts/subscriptions')
  Future<PodcastSubscriptionListResponse> listSubscriptions(
    @Query('page') int page,
    @Query('size') int size,
    @Query('category_id') int? categoryId,
    @Query('status') String? status,
  );

  @GET('/podcasts/subscriptions/{subscriptionId}')
  Future<PodcastSubscriptionModel> getSubscription(
    @Path('subscriptionId') int subscriptionId,
  );

  @DELETE('/podcasts/subscriptions/{subscriptionId}')
  Future<void> deleteSubscription(@Path('subscriptionId') int subscriptionId);

  @POST('/podcasts/subscriptions/bulk-delete')
  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions(
    @Body() PodcastSubscriptionBulkDeleteRequest request,
  );

  @POST('/podcasts/subscriptions/{subscriptionId}/refresh')
  Future<void> refreshSubscription(@Path('subscriptionId') int subscriptionId);

  @POST('/podcasts/subscriptions/{subscriptionId}/reparse')
  Future<ReparseResponse> reparseSubscription(
    @Path('subscriptionId') int subscriptionId,
    @Query('force_all') bool forceAll,
  );

  @GET('/podcasts/subscriptions/{subscriptionId}/schedule')
  Future<ScheduleConfigResponse> getSubscriptionSchedule(
    @Path('subscriptionId') int subscriptionId,
  );

  @PATCH('/podcasts/subscriptions/{subscriptionId}/schedule')
  Future<ScheduleConfigResponse> updateSubscriptionSchedule(
    @Path('subscriptionId') int subscriptionId,
    @Body() ScheduleConfigUpdateRequest request,
  );

  // === Episode Management ===

  @GET('/podcasts/episodes/feed')
  Future<PodcastFeedResponse> getPodcastFeed(
    @Query('page') int page,
    @Query('page_size') int pageSize,
    @Query('cursor') String? cursor,
  );

  // === 三刊与站点动态（读 /api/v1/site；Phase G 起需登录态，JWT 由 Dio 拦截器附加） ===

  @GET('/site/meta')
  Future<SiteMeta> getSiteMeta();

  @GET('/site/reports/{kind}/latest')
  Future<SiteReport> getLatestSiteReport(@Path('kind') String kind);

  @GET('/site/reports/{kind}/{reportKey}')
  Future<SiteReport> getSiteReport(
    @Path('kind') String kind,
    @Path('reportKey') String reportKey,
  );

  @GET('/site/reports/{kind}')
  Future<SiteReportArchiveResponse> getSiteReportArchive(
    @Path('kind') String kind, {
    @Query('page') int? page,
    @Query('size') int? size,
  });

  @GET('/site/episodes')
  Future<SiteSelectedEpisodesResponse> getSiteSelectedEpisodes({
    @Query('limit') int? limit,
  });

  @GET('/site/episodes/all')
  Future<SiteAllEpisodesResponse> getSiteAllEpisodes({
    @Query('page') int? page,
    @Query('size') int? size,
  });

  @GET('/site/episodes/{episodeId}')
  Future<SiteEpisodeDetailResponse> getSiteEpisodeDetail(
    @Path('episodeId') int episodeId,
  );

  // === 发现（后端代理 iTunes，Phase E） ===

  @GET('/discover')
  Future<DiscoverSearchResponse> discoverSearch(
    @Query('q') String query, {
    @Query('limit') int? limit,
  });

  @GET('/discover/charts')
  Future<DiscoverChartsResponse> discoverCharts(
    @Query('country') String country, {
    @Query('limit') int? limit,
  });

  // === 收藏同步（per-user，Phase E） ===

  @GET('/podcasts/favorites')
  Future<FavoritesListResponse> listFavorites({
    @Query('page') int? page,
    @Query('size') int? size,
  });

  @GET('/podcasts/favorites/{episodeId}/status')
  Future<FavoriteStatusResponse> getFavoriteStatus(
    @Path('episodeId') int episodeId,
  );

  @PUT('/podcasts/favorites/{episodeId}')
  Future<FavoriteStatusResponse> addFavorite(@Path('episodeId') int episodeId);

  @DELETE('/podcasts/favorites/{episodeId}')
  Future<FavoriteStatusResponse> removeFavorite(
    @Path('episodeId') int episodeId,
  );

  @GET('/podcasts/episodes')
  Future<PodcastEpisodeListResponse> listEpisodes(
    @Query('subscription_id') int? subscriptionId,
    @Query('page') int page,
    @Query('size') int size,
    @Query('has_summary') bool? hasSummary,
  );

  @GET('/podcasts/episodes/{episodeId}')
  Future<PodcastEpisodeModel> getEpisode(
    @Path('episodeId') int episodeId,
  );

  // === Summary Management ===

  @POST('/podcasts/episodes/{episodeId}/summary')
  Future<PodcastSummaryStartResponse> generateSummary(
    @Path('episodeId') int episodeId,
    @Body() PodcastSummaryRequest request,
  );

  @GET('/podcasts/summaries/models')
  Future<SummaryModelsResponse> getSummaryModels();

  @GET('/podcasts/summaries/pending')
  Future<SimpleResponse> getPendingSummaries();

  // === Search ===

  @GET('/podcasts/search')
  Future<PodcastEpisodeListResponse> searchPodcasts(
    @Query('q') String query,
    @Query('search_in') String? searchIn,
    @Query('page') int page,
    @Query('size') int size,
  );

  // === Statistics ===

  @GET('/podcasts/stats/profile')
  Future<ProfileStatsModel> getProfileStats();

  // === Transcription Management ===

  @GET('/podcasts/episodes/{episodeId}/transcription')
  Future<PodcastTranscriptionResponse> getTranscription(
    @Path('episodeId') int episodeId,
  );

  @POST('/podcasts/episodes/{episodeId}/transcribe')
  Future<PodcastTranscriptionResponse> startTranscription(
    @Path('episodeId') int episodeId,
    @Body() PodcastTranscriptionRequest request,
  );

  @DELETE('/podcasts/episodes/{episodeId}/transcription')
  Future<void> deleteTranscription(@Path('episodeId') int episodeId);

  // === Conversation Management ===

  @GET('/podcasts/episodes/{episodeId}/conversation-sessions')
  Future<ConversationSessionListResponse> getConversationSessions(
    @Path('episodeId') int episodeId,
  );

  @POST('/podcasts/episodes/{episodeId}/conversation-sessions')
  Future<ConversationSession> createConversationSession(
    @Path('episodeId') int episodeId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/podcasts/episodes/{episodeId}/conversation-sessions/{sessionId}')
  Future<PodcastConversationClearResponse> deleteConversationSession(
    @Path('episodeId') int episodeId,
    @Path('sessionId') int sessionId,
  );

  @GET('/podcasts/episodes/{episodeId}/conversations')
  Future<PodcastConversationHistoryResponse> getConversationHistory(
    @Path('episodeId') int episodeId,
    @Query('limit') int limit,
    @Query('session_id') int? sessionId,
  );

  @POST('/podcasts/episodes/{episodeId}/conversations')
  Future<PodcastConversationSendResponse> sendConversationMessage(
    @Path('episodeId') int episodeId,
    @Body() PodcastConversationSendRequest request,
  );

  @DELETE('/podcasts/episodes/{episodeId}/conversations')
  Future<PodcastConversationClearResponse> clearConversationHistory(
    @Path('episodeId') int episodeId,
    @Query('session_id') int? sessionId,
  );

  @GET('/podcasts/subscriptions/schedule/all')
  Future<List<ScheduleConfigResponse>> getAllSubscriptionSchedules();

  @POST('/podcasts/subscriptions/schedule/batch-update')
  Future<List<ScheduleConfigResponse>> batchUpdateSubscriptionSchedules(
    @Body() Map<String, dynamic> requestData,
  );

  // === Highlights Management ===

  @GET('/podcasts/highlights')
  Future<HighlightsListResponse> getHighlights(
    @Query('date') String? date,
    @Query('page') int page,
    @Query('per_page') int perPage,
    @Query('episode_id') int? episodeId,
  );

  @GET('/podcasts/highlights/dates')
  Future<HighlightDatesResponse> getHighlightDates();

  @GET('/podcasts/highlights/stats')
  Future<HighlightStatsResponse> getHighlightStats();

  @POST('/podcasts/episodes/{episodeId}/highlights/extract')
  Future<HighlightExtractResponse> extractEpisodeHighlights(
    @Path('episodeId') int episodeId,
  );

  @POST('/podcasts/highlights/{highlightId}/toggle-favorite')
  Future<void> toggleHighlightFavorite(@Path('highlightId') int highlightId);

  @DELETE('/podcasts/highlights/{highlightId}')
  Future<void> deleteHighlight(@Path('highlightId') int highlightId);
}
