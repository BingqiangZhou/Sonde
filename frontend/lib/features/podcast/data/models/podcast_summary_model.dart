import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'podcast_summary_model.g.dart';

@JsonSerializable()
class PodcastSummaryResponse extends Equatable {

  const PodcastSummaryResponse({
    required this.episodeId,
    required this.summary,
    required this.version,
    required this.transcriptUsed, required this.generatedAt, required this.wordCount, this.confidenceScore,
    this.modelUsed,
    this.processingTime,
  });

  factory PodcastSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastSummaryResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  final String summary;
  final String version;
  @JsonKey(name: 'confidence_score')
  final double? confidenceScore;
  @JsonKey(name: 'transcript_used', defaultValue: false)
  final bool transcriptUsed;
  @JsonKey(name: 'generated_at')
  final DateTime generatedAt;
  @JsonKey(name: 'word_count')
  final int wordCount;
  @JsonKey(name: 'model_used')
  final String? modelUsed;
  @JsonKey(name: 'processing_time')
  final double? processingTime;

  Map<String, dynamic> toJson() => _$PodcastSummaryResponseToJson(this);

  @override
  List<Object?> get props => [
    episodeId,
    summary,
    version,
    confidenceScore,
    transcriptUsed,
    generatedAt,
    wordCount,
    modelUsed,
    processingTime,
  ];
}

@JsonSerializable()
class PodcastSummaryStartResponse extends Equatable {

  const PodcastSummaryStartResponse({
    required this.episodeId,
    required this.summaryStatus,
    required this.acceptedAt,
    required this.messageEn,
    required this.messageZh,
  });

  factory PodcastSummaryStartResponse.fromJson(Map<String, dynamic> json) =>
      _$PodcastSummaryStartResponseFromJson(json);
  @JsonKey(name: 'episode_id')
  final int episodeId;
  @JsonKey(name: 'summary_status')
  final String summaryStatus;
  @JsonKey(name: 'accepted_at')
  final DateTime acceptedAt;
  @JsonKey(name: 'message_en')
  final String messageEn;
  @JsonKey(name: 'message_zh')
  final String messageZh;

  Map<String, dynamic> toJson() => _$PodcastSummaryStartResponseToJson(this);

  @override
  List<Object?> get props => [
    episodeId,
    summaryStatus,
    acceptedAt,
    messageEn,
    messageZh,
  ];
}

@JsonSerializable()
class PodcastSummaryRequest extends Equatable {

  const PodcastSummaryRequest({
    this.forceRegenerate = false,
    this.useTranscript,
    this.summaryModel,
    this.customPrompt,
  });
  @JsonKey(name: 'force_regenerate')
  final bool forceRegenerate;
  @JsonKey(name: 'use_transcript')
  final bool? useTranscript;
  @JsonKey(name: 'summary_model')
  final String? summaryModel;
  @JsonKey(name: 'custom_prompt')
  final String? customPrompt;

  Map<String, dynamic> toJson() => _$PodcastSummaryRequestToJson(this);

  @override
  List<Object?> get props => [
    forceRegenerate,
    useTranscript,
    summaryModel,
    customPrompt,
  ];
}

@JsonSerializable()

class SummaryModelInfo extends Equatable {

  const SummaryModelInfo({
    required this.id,
    required this.name,
    required this.displayName,
    required this.provider,
    required this.modelId,
    required this.isDefault,
  });

  factory SummaryModelInfo.fromJson(Map<String, dynamic> json) =>
      _$SummaryModelInfoFromJson(json);
  final int id;
  final String name;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String provider;
  @JsonKey(name: 'model_id')
  final String modelId;
  @JsonKey(name: 'is_default')
  final bool isDefault;

  Map<String, dynamic> toJson() => _$SummaryModelInfoToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    displayName,
    provider,
    modelId,
    isDefault,
  ];
}

/// 可用总结模型列表响应
@JsonSerializable()
class SummaryModelsResponse extends Equatable {

  const SummaryModelsResponse({required this.models, required this.total});

  factory SummaryModelsResponse.fromJson(Map<String, dynamic> json) =>
      _$SummaryModelsResponseFromJson(json);
  final List<SummaryModelInfo> models;
  final int total;

  Map<String, dynamic> toJson() => _$SummaryModelsResponseToJson(this);

  @override
  List<Object?> get props => [models, total];
}
