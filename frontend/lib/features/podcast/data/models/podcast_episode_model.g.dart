// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_episode_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PodcastEpisodeModel _$PodcastEpisodeModelFromJson(Map<String, dynamic> json) =>
    PodcastEpisodeModel(
      id: (json['id'] as num).toInt(),
      subscriptionId: (json['subscription_id'] as num).toInt(),
      title: json['title'] as String,
      audioUrl: json['audio_url'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      subscriptionImageUrl: json['subscription_image_url'] as String?,
      subscriptionTitle: json['subscription_title'] as String?,
      description: json['description'] as String?,
      audioDuration: (json['audio_duration'] as num?)?.toInt(),
      audioFileSize: (json['audio_file_size'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
      itemLink: json['item_link'] as String?,
      transcriptUrl: json['transcript_url'] as String?,
      transcriptContent: json['transcript_content'] as String?,
      aiSummary: json['ai_summary'] as String?,
      summaryVersion: json['summary_version'] as String?,
      aiConfidenceScore: (json['ai_confidence_score'] as num?)?.toDouble(),
      season: (json['season'] as num?)?.toInt(),
      episodeNumber: (json['episode_number'] as num?)?.toInt(),
      explicit: json['explicit'] as bool? ?? false,
      status: json['status'] as String? ?? 'published',
      metadata: json['metadata'] as Map<String, dynamic>?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      summaryStatus: json['summary_status'] as String?,
      summaryErrorMessage: json['summary_error_message'] as String?,
      summaryModelUsed: json['summary_model_used'] as String?,
      summaryProcessingTime: (json['summary_processing_time'] as num?)
          ?.toDouble(),
      subscription: json['subscription'] as Map<String, dynamic>?,
      relatedEpisodes: json['related_episodes'] as List<dynamic>?,
      insightScore: (json['insight_score'] as num?)?.toInt(),
      insightSelected: json['insight_selected'] as bool?,
      insightCategory: json['insight_category'] as String?,
      titleZh: json['title_zh'] as String?,
      summaryZh: json['summary_zh'] as String?,
      reasonZh: json['reason_zh'] as String?,
    );

Map<String, dynamic> _$PodcastEpisodeModelToJson(
  PodcastEpisodeModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'subscription_id': instance.subscriptionId,
  'subscription_image_url': instance.subscriptionImageUrl,
  'title': instance.title,
  'subscription_title': instance.subscriptionTitle,
  'description': instance.description,
  'audio_url': instance.audioUrl,
  'audio_duration': instance.audioDuration,
  'audio_file_size': instance.audioFileSize,
  'published_at': instance.publishedAt.toIso8601String(),
  'image_url': instance.imageUrl,
  'item_link': instance.itemLink,
  'transcript_url': instance.transcriptUrl,
  'transcript_content': instance.transcriptContent,
  'ai_summary': instance.aiSummary,
  'summary_version': instance.summaryVersion,
  'ai_confidence_score': instance.aiConfidenceScore,
  'season': instance.season,
  'episode_number': instance.episodeNumber,
  'explicit': instance.explicit,
  'status': instance.status,
  'metadata': instance.metadata,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'summary_status': instance.summaryStatus,
  'summary_error_message': instance.summaryErrorMessage,
  'summary_model_used': instance.summaryModelUsed,
  'summary_processing_time': instance.summaryProcessingTime,
  'subscription': instance.subscription,
  'related_episodes': instance.relatedEpisodes,
  'insight_score': instance.insightScore,
  'insight_selected': instance.insightSelected,
  'insight_category': instance.insightCategory,
  'title_zh': instance.titleZh,
  'summary_zh': instance.summaryZh,
  'reason_zh': instance.reasonZh,
};

PodcastEpisodeListResponse _$PodcastEpisodeListResponseFromJson(
  Map<String, dynamic> json,
) => PodcastEpisodeListResponse(
  episodes: (json['items'] as List<dynamic>)
      .map((e) => PodcastEpisodeModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  size: (json['size'] as num).toInt(),
  pages: (json['pages'] as num).toInt(),
  subscriptionId: (json['subscription_id'] as num).toInt(),
  nextCursor: json['next_cursor'] as String?,
);

Map<String, dynamic> _$PodcastEpisodeListResponseToJson(
  PodcastEpisodeListResponse instance,
) => <String, dynamic>{
  'items': instance.episodes,
  'total': instance.total,
  'page': instance.page,
  'size': instance.size,
  'pages': instance.pages,
  'subscription_id': instance.subscriptionId,
  'next_cursor': instance.nextCursor,
};

PodcastFeedResponse _$PodcastFeedResponseFromJson(Map<String, dynamic> json) =>
    PodcastFeedResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => PodcastEpisodeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
      total: (json['total'] as num).toInt(),
      nextPage: (json['next_page'] as num?)?.toInt(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$PodcastFeedResponseToJson(
  PodcastFeedResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'has_more': instance.hasMore,
  'next_page': instance.nextPage,
  'next_cursor': instance.nextCursor,
  'total': instance.total,
};
