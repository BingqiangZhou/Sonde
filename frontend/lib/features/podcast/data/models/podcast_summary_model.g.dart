// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PodcastSummaryResponse _$PodcastSummaryResponseFromJson(
  Map<String, dynamic> json,
) => PodcastSummaryResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  summary: json['summary'] as String,
  version: json['version'] as String,
  transcriptUsed: json['transcript_used'] as bool? ?? false,
  generatedAt: DateTime.parse(json['generated_at'] as String),
  wordCount: (json['word_count'] as num).toInt(),
  confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
  modelUsed: json['model_used'] as String?,
  processingTime: (json['processing_time'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PodcastSummaryResponseToJson(
  PodcastSummaryResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'summary': instance.summary,
  'version': instance.version,
  'confidence_score': instance.confidenceScore,
  'transcript_used': instance.transcriptUsed,
  'generated_at': instance.generatedAt.toIso8601String(),
  'word_count': instance.wordCount,
  'model_used': instance.modelUsed,
  'processing_time': instance.processingTime,
};

PodcastSummaryStartResponse _$PodcastSummaryStartResponseFromJson(
  Map<String, dynamic> json,
) => PodcastSummaryStartResponse(
  episodeId: (json['episode_id'] as num).toInt(),
  summaryStatus: json['summary_status'] as String,
  acceptedAt: DateTime.parse(json['accepted_at'] as String),
  messageEn: json['message_en'] as String,
  messageZh: json['message_zh'] as String,
);

Map<String, dynamic> _$PodcastSummaryStartResponseToJson(
  PodcastSummaryStartResponse instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'summary_status': instance.summaryStatus,
  'accepted_at': instance.acceptedAt.toIso8601String(),
  'message_en': instance.messageEn,
  'message_zh': instance.messageZh,
};

PodcastSummaryRequest _$PodcastSummaryRequestFromJson(
  Map<String, dynamic> json,
) => PodcastSummaryRequest(
  forceRegenerate: json['force_regenerate'] as bool? ?? false,
  useTranscript: json['use_transcript'] as bool?,
  summaryModel: json['summary_model'] as String?,
  customPrompt: json['custom_prompt'] as String?,
);

Map<String, dynamic> _$PodcastSummaryRequestToJson(
  PodcastSummaryRequest instance,
) => <String, dynamic>{
  'force_regenerate': instance.forceRegenerate,
  'use_transcript': instance.useTranscript,
  'summary_model': instance.summaryModel,
  'custom_prompt': instance.customPrompt,
};

SummaryModelInfo _$SummaryModelInfoFromJson(Map<String, dynamic> json) =>
    SummaryModelInfo(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      provider: json['provider'] as String,
      modelId: json['model_id'] as String,
      isDefault: json['is_default'] as bool,
    );

Map<String, dynamic> _$SummaryModelInfoToJson(SummaryModelInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'display_name': instance.displayName,
      'provider': instance.provider,
      'model_id': instance.modelId,
      'is_default': instance.isDefault,
    };

SummaryModelsResponse _$SummaryModelsResponseFromJson(
  Map<String, dynamic> json,
) => SummaryModelsResponse(
  models: (json['models'] as List<dynamic>)
      .map((e) => SummaryModelInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$SummaryModelsResponseToJson(
  SummaryModelsResponse instance,
) => <String, dynamic>{'models': instance.models, 'total': instance.total};
