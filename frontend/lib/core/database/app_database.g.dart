// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<DownloadStatus>($DownloadTasksTable.$converterstatus);
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    episodeId,
    audioUrl,
    localPath,
    status,
    progress,
    fileSize,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeIdMeta);
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      status: $DownloadTasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStatus, int, int> $converterstatus =
      const EnumIndexConverter<DownloadStatus>(DownloadStatus.values);
}

class DownloadTask extends DataClass implements Insertable<DownloadTask> {
  final int id;
  final int episodeId;
  final String audioUrl;
  final String? localPath;
  final DownloadStatus status;
  final double progress;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DownloadTask({
    required this.id,
    required this.episodeId,
    required this.audioUrl,
    this.localPath,
    required this.status,
    required this.progress,
    this.fileSize,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['episode_id'] = Variable<int>(episodeId);
    map['audio_url'] = Variable<String>(audioUrl);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    {
      map['status'] = Variable<int>(
        $DownloadTasksTable.$converterstatus.toSql(status),
      );
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      episodeId: Value(episodeId),
      audioUrl: Value(audioUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      status: Value(status),
      progress: Value(progress),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTask(
      id: serializer.fromJson<int>(json['id']),
      episodeId: serializer.fromJson<int>(json['episodeId']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      status: $DownloadTasksTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      progress: serializer.fromJson<double>(json['progress']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'episodeId': serializer.toJson<int>(episodeId),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'localPath': serializer.toJson<String?>(localPath),
      'status': serializer.toJson<int>(
        $DownloadTasksTable.$converterstatus.toJson(status),
      ),
      'progress': serializer.toJson<double>(progress),
      'fileSize': serializer.toJson<int?>(fileSize),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadTask copyWith({
    int? id,
    int? episodeId,
    String? audioUrl,
    Value<String?> localPath = const Value.absent(),
    DownloadStatus? status,
    double? progress,
    Value<int?> fileSize = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadTask(
    id: id ?? this.id,
    episodeId: episodeId ?? this.episodeId,
    audioUrl: audioUrl ?? this.audioUrl,
    localPath: localPath.present ? localPath.value : this.localPath,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadTask copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTask(
      id: data.id.present ? data.id.value : this.id,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTask(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('localPath: $localPath, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    episodeId,
    audioUrl,
    localPath,
    status,
    progress,
    fileSize,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTask &&
          other.id == this.id &&
          other.episodeId == this.episodeId &&
          other.audioUrl == this.audioUrl &&
          other.localPath == this.localPath &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.fileSize == this.fileSize &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTask> {
  final Value<int> id;
  final Value<int> episodeId;
  final Value<String> audioUrl;
  final Value<String?> localPath;
  final Value<DownloadStatus> status;
  final Value<double> progress;
  final Value<int?> fileSize;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    this.id = const Value.absent(),
    required int episodeId,
    required String audioUrl,
    this.localPath = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : episodeId = Value(episodeId),
       audioUrl = Value(audioUrl);
  static Insertable<DownloadTask> custom({
    Expression<int>? id,
    Expression<int>? episodeId,
    Expression<String>? audioUrl,
    Expression<String>? localPath,
    Expression<int>? status,
    Expression<double>? progress,
    Expression<int>? fileSize,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (episodeId != null) 'episode_id': episodeId,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (localPath != null) 'local_path': localPath,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (fileSize != null) 'file_size': fileSize,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<int>? id,
    Value<int>? episodeId,
    Value<String>? audioUrl,
    Value<String?>? localPath,
    Value<DownloadStatus>? status,
    Value<double>? progress,
    Value<int?>? fileSize,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      episodeId: episodeId ?? this.episodeId,
      audioUrl: audioUrl ?? this.audioUrl,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $DownloadTasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('episodeId: $episodeId, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('localPath: $localPath, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $EpisodesCacheTable extends EpisodesCache
    with TableInfo<$EpisodesCacheTable, EpisodesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subscriptionIdMeta = const VerificationMeta(
    'subscriptionId',
  );
  @override
  late final GeneratedColumn<int> subscriptionId = GeneratedColumn<int>(
    'subscription_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioDurationMeta = const VerificationMeta(
    'audioDuration',
  );
  @override
  late final GeneratedColumn<int> audioDuration = GeneratedColumn<int>(
    'audio_duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subscriptionTitleMeta = const VerificationMeta(
    'subscriptionTitle',
  );
  @override
  late final GeneratedColumn<String> subscriptionTitle =
      GeneratedColumn<String>(
        'subscription_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _subscriptionImageUrlMeta =
      const VerificationMeta('subscriptionImageUrl');
  @override
  late final GeneratedColumn<String> subscriptionImageUrl =
      GeneratedColumn<String>(
        'subscription_image_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiSummaryMeta = const VerificationMeta(
    'aiSummary',
  );
  @override
  late final GeneratedColumn<String> aiSummary = GeneratedColumn<String>(
    'ai_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subscriptionId,
    title,
    audioUrl,
    imageUrl,
    audioDuration,
    subscriptionTitle,
    subscriptionImageUrl,
    publishedAt,
    updatedAt,
    description,
    aiSummary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subscription_id')) {
      context.handle(
        _subscriptionIdMeta,
        subscriptionId.isAcceptableOrUnknown(
          data['subscription_id']!,
          _subscriptionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subscriptionIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
        _audioDurationMeta,
        audioDuration.isAcceptableOrUnknown(
          data['audio_duration']!,
          _audioDurationMeta,
        ),
      );
    }
    if (data.containsKey('subscription_title')) {
      context.handle(
        _subscriptionTitleMeta,
        subscriptionTitle.isAcceptableOrUnknown(
          data['subscription_title']!,
          _subscriptionTitleMeta,
        ),
      );
    }
    if (data.containsKey('subscription_image_url')) {
      context.handle(
        _subscriptionImageUrlMeta,
        subscriptionImageUrl.isAcceptableOrUnknown(
          data['subscription_image_url']!,
          _subscriptionImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('ai_summary')) {
      context.handle(
        _aiSummaryMeta,
        aiSummary.isAcceptableOrUnknown(data['ai_summary']!, _aiSummaryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpisodesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subscriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscription_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      audioDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_duration'],
      ),
      subscriptionTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subscription_title'],
      ),
      subscriptionImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subscription_image_url'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      aiSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_summary'],
      ),
    );
  }

  @override
  $EpisodesCacheTable createAlias(String alias) {
    return $EpisodesCacheTable(attachedDatabase, alias);
  }
}

class EpisodesCacheData extends DataClass
    implements Insertable<EpisodesCacheData> {
  final int id;
  final int subscriptionId;
  final String title;
  final String audioUrl;
  final String? imageUrl;
  final int? audioDuration;
  final String? subscriptionTitle;
  final String? subscriptionImageUrl;
  final DateTime publishedAt;
  final DateTime updatedAt;

  /// Collapsed one-line description (feed semantics).
  final String? description;

  /// Full AI summary text kept for offline summary reading.
  final String? aiSummary;
  const EpisodesCacheData({
    required this.id,
    required this.subscriptionId,
    required this.title,
    required this.audioUrl,
    this.imageUrl,
    this.audioDuration,
    this.subscriptionTitle,
    this.subscriptionImageUrl,
    required this.publishedAt,
    required this.updatedAt,
    this.description,
    this.aiSummary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subscription_id'] = Variable<int>(subscriptionId);
    map['title'] = Variable<String>(title);
    map['audio_url'] = Variable<String>(audioUrl);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<int>(audioDuration);
    }
    if (!nullToAbsent || subscriptionTitle != null) {
      map['subscription_title'] = Variable<String>(subscriptionTitle);
    }
    if (!nullToAbsent || subscriptionImageUrl != null) {
      map['subscription_image_url'] = Variable<String>(subscriptionImageUrl);
    }
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || aiSummary != null) {
      map['ai_summary'] = Variable<String>(aiSummary);
    }
    return map;
  }

  EpisodesCacheCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCacheCompanion(
      id: Value(id),
      subscriptionId: Value(subscriptionId),
      title: Value(title),
      audioUrl: Value(audioUrl),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      subscriptionTitle: subscriptionTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionTitle),
      subscriptionImageUrl: subscriptionImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionImageUrl),
      publishedAt: Value(publishedAt),
      updatedAt: Value(updatedAt),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      aiSummary: aiSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(aiSummary),
    );
  }

  factory EpisodesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodesCacheData(
      id: serializer.fromJson<int>(json['id']),
      subscriptionId: serializer.fromJson<int>(json['subscriptionId']),
      title: serializer.fromJson<String>(json['title']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      audioDuration: serializer.fromJson<int?>(json['audioDuration']),
      subscriptionTitle: serializer.fromJson<String?>(
        json['subscriptionTitle'],
      ),
      subscriptionImageUrl: serializer.fromJson<String?>(
        json['subscriptionImageUrl'],
      ),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      description: serializer.fromJson<String?>(json['description']),
      aiSummary: serializer.fromJson<String?>(json['aiSummary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subscriptionId': serializer.toJson<int>(subscriptionId),
      'title': serializer.toJson<String>(title),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'audioDuration': serializer.toJson<int?>(audioDuration),
      'subscriptionTitle': serializer.toJson<String?>(subscriptionTitle),
      'subscriptionImageUrl': serializer.toJson<String?>(subscriptionImageUrl),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'description': serializer.toJson<String?>(description),
      'aiSummary': serializer.toJson<String?>(aiSummary),
    };
  }

  EpisodesCacheData copyWith({
    int? id,
    int? subscriptionId,
    String? title,
    String? audioUrl,
    Value<String?> imageUrl = const Value.absent(),
    Value<int?> audioDuration = const Value.absent(),
    Value<String?> subscriptionTitle = const Value.absent(),
    Value<String?> subscriptionImageUrl = const Value.absent(),
    DateTime? publishedAt,
    DateTime? updatedAt,
    Value<String?> description = const Value.absent(),
    Value<String?> aiSummary = const Value.absent(),
  }) => EpisodesCacheData(
    id: id ?? this.id,
    subscriptionId: subscriptionId ?? this.subscriptionId,
    title: title ?? this.title,
    audioUrl: audioUrl ?? this.audioUrl,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    audioDuration: audioDuration.present
        ? audioDuration.value
        : this.audioDuration,
    subscriptionTitle: subscriptionTitle.present
        ? subscriptionTitle.value
        : this.subscriptionTitle,
    subscriptionImageUrl: subscriptionImageUrl.present
        ? subscriptionImageUrl.value
        : this.subscriptionImageUrl,
    publishedAt: publishedAt ?? this.publishedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    description: description.present ? description.value : this.description,
    aiSummary: aiSummary.present ? aiSummary.value : this.aiSummary,
  );
  EpisodesCacheData copyWithCompanion(EpisodesCacheCompanion data) {
    return EpisodesCacheData(
      id: data.id.present ? data.id.value : this.id,
      subscriptionId: data.subscriptionId.present
          ? data.subscriptionId.value
          : this.subscriptionId,
      title: data.title.present ? data.title.value : this.title,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      subscriptionTitle: data.subscriptionTitle.present
          ? data.subscriptionTitle.value
          : this.subscriptionTitle,
      subscriptionImageUrl: data.subscriptionImageUrl.present
          ? data.subscriptionImageUrl.value
          : this.subscriptionImageUrl,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      description: data.description.present
          ? data.description.value
          : this.description,
      aiSummary: data.aiSummary.present ? data.aiSummary.value : this.aiSummary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCacheData(')
          ..write('id: $id, ')
          ..write('subscriptionId: $subscriptionId, ')
          ..write('title: $title, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('subscriptionTitle: $subscriptionTitle, ')
          ..write('subscriptionImageUrl: $subscriptionImageUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('description: $description, ')
          ..write('aiSummary: $aiSummary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subscriptionId,
    title,
    audioUrl,
    imageUrl,
    audioDuration,
    subscriptionTitle,
    subscriptionImageUrl,
    publishedAt,
    updatedAt,
    description,
    aiSummary,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodesCacheData &&
          other.id == this.id &&
          other.subscriptionId == this.subscriptionId &&
          other.title == this.title &&
          other.audioUrl == this.audioUrl &&
          other.imageUrl == this.imageUrl &&
          other.audioDuration == this.audioDuration &&
          other.subscriptionTitle == this.subscriptionTitle &&
          other.subscriptionImageUrl == this.subscriptionImageUrl &&
          other.publishedAt == this.publishedAt &&
          other.updatedAt == this.updatedAt &&
          other.description == this.description &&
          other.aiSummary == this.aiSummary);
}

class EpisodesCacheCompanion extends UpdateCompanion<EpisodesCacheData> {
  final Value<int> id;
  final Value<int> subscriptionId;
  final Value<String> title;
  final Value<String> audioUrl;
  final Value<String?> imageUrl;
  final Value<int?> audioDuration;
  final Value<String?> subscriptionTitle;
  final Value<String?> subscriptionImageUrl;
  final Value<DateTime> publishedAt;
  final Value<DateTime> updatedAt;
  final Value<String?> description;
  final Value<String?> aiSummary;
  const EpisodesCacheCompanion({
    this.id = const Value.absent(),
    this.subscriptionId = const Value.absent(),
    this.title = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.subscriptionTitle = const Value.absent(),
    this.subscriptionImageUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.description = const Value.absent(),
    this.aiSummary = const Value.absent(),
  });
  EpisodesCacheCompanion.insert({
    this.id = const Value.absent(),
    required int subscriptionId,
    required String title,
    required String audioUrl,
    this.imageUrl = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.subscriptionTitle = const Value.absent(),
    this.subscriptionImageUrl = const Value.absent(),
    required DateTime publishedAt,
    required DateTime updatedAt,
    this.description = const Value.absent(),
    this.aiSummary = const Value.absent(),
  }) : subscriptionId = Value(subscriptionId),
       title = Value(title),
       audioUrl = Value(audioUrl),
       publishedAt = Value(publishedAt),
       updatedAt = Value(updatedAt);
  static Insertable<EpisodesCacheData> custom({
    Expression<int>? id,
    Expression<int>? subscriptionId,
    Expression<String>? title,
    Expression<String>? audioUrl,
    Expression<String>? imageUrl,
    Expression<int>? audioDuration,
    Expression<String>? subscriptionTitle,
    Expression<String>? subscriptionImageUrl,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? description,
    Expression<String>? aiSummary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subscriptionId != null) 'subscription_id': subscriptionId,
      if (title != null) 'title': title,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (subscriptionTitle != null) 'subscription_title': subscriptionTitle,
      if (subscriptionImageUrl != null)
        'subscription_image_url': subscriptionImageUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (description != null) 'description': description,
      if (aiSummary != null) 'ai_summary': aiSummary,
    });
  }

  EpisodesCacheCompanion copyWith({
    Value<int>? id,
    Value<int>? subscriptionId,
    Value<String>? title,
    Value<String>? audioUrl,
    Value<String?>? imageUrl,
    Value<int?>? audioDuration,
    Value<String?>? subscriptionTitle,
    Value<String?>? subscriptionImageUrl,
    Value<DateTime>? publishedAt,
    Value<DateTime>? updatedAt,
    Value<String?>? description,
    Value<String?>? aiSummary,
  }) {
    return EpisodesCacheCompanion(
      id: id ?? this.id,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      title: title ?? this.title,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      subscriptionTitle: subscriptionTitle ?? this.subscriptionTitle,
      subscriptionImageUrl: subscriptionImageUrl ?? this.subscriptionImageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subscriptionId.present) {
      map['subscription_id'] = Variable<int>(subscriptionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<int>(audioDuration.value);
    }
    if (subscriptionTitle.present) {
      map['subscription_title'] = Variable<String>(subscriptionTitle.value);
    }
    if (subscriptionImageUrl.present) {
      map['subscription_image_url'] = Variable<String>(
        subscriptionImageUrl.value,
      );
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (aiSummary.present) {
      map['ai_summary'] = Variable<String>(aiSummary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCacheCompanion(')
          ..write('id: $id, ')
          ..write('subscriptionId: $subscriptionId, ')
          ..write('title: $title, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('subscriptionTitle: $subscriptionTitle, ')
          ..write('subscriptionImageUrl: $subscriptionImageUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('description: $description, ')
          ..write('aiSummary: $aiSummary')
          ..write(')'))
        .toString();
  }
}

class $ResponseCacheTable extends ResponseCache
    with TableInfo<$ResponseCacheTable, ResponseCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResponseCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload, cachedAt, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'response_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResponseCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ResponseCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResponseCacheData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $ResponseCacheTable createAlias(String alias) {
    return $ResponseCacheTable(attachedDatabase, alias);
  }
}

class ResponseCacheData extends DataClass
    implements Insertable<ResponseCacheData> {
  final String key;
  final String payload;
  final DateTime cachedAt;
  final DateTime expiresAt;
  const ResponseCacheData({
    required this.key,
    required this.payload,
    required this.cachedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  ResponseCacheCompanion toCompanion(bool nullToAbsent) {
    return ResponseCacheCompanion(
      key: Value(key),
      payload: Value(payload),
      cachedAt: Value(cachedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory ResponseCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResponseCacheData(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  ResponseCacheData copyWith({
    String? key,
    String? payload,
    DateTime? cachedAt,
    DateTime? expiresAt,
  }) => ResponseCacheData(
    key: key ?? this.key,
    payload: payload ?? this.payload,
    cachedAt: cachedAt ?? this.cachedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  ResponseCacheData copyWithCompanion(ResponseCacheCompanion data) {
    return ResponseCacheData(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResponseCacheData(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, cachedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResponseCacheData &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.cachedAt == this.cachedAt &&
          other.expiresAt == this.expiresAt);
}

class ResponseCacheCompanion extends UpdateCompanion<ResponseCacheData> {
  final Value<String> key;
  final Value<String> payload;
  final Value<DateTime> cachedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const ResponseCacheCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResponseCacheCompanion.insert({
    required String key,
    required String payload,
    this.cachedAt = const Value.absent(),
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload),
       expiresAt = Value(expiresAt);
  static Insertable<ResponseCacheData> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<DateTime>? cachedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResponseCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<DateTime>? cachedAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return ResponseCacheCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResponseCacheCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStatesTable extends PlaybackStates
    with TableInfo<$PlaybackStatesTable, PlaybackState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playbackRateMeta = const VerificationMeta(
    'playbackRate',
  );
  @override
  late final GeneratedColumn<double> playbackRate = GeneratedColumn<double>(
    'playback_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _isPlayingMeta = const VerificationMeta(
    'isPlaying',
  );
  @override
  late final GeneratedColumn<bool> isPlaying = GeneratedColumn<bool>(
    'is_playing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_playing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    episodeId,
    position,
    playbackRate,
    isPlaying,
    playCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('playback_rate')) {
      context.handle(
        _playbackRateMeta,
        playbackRate.isAcceptableOrUnknown(
          data['playback_rate']!,
          _playbackRateMeta,
        ),
      );
    }
    if (data.containsKey('is_playing')) {
      context.handle(
        _isPlayingMeta,
        isPlaying.isAcceptableOrUnknown(data['is_playing']!, _isPlayingMeta),
      );
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  PlaybackState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackState(
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      playbackRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}playback_rate'],
      )!,
      isPlaying: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_playing'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackStatesTable createAlias(String alias) {
    return $PlaybackStatesTable(attachedDatabase, alias);
  }
}

class PlaybackState extends DataClass implements Insertable<PlaybackState> {
  final int episodeId;
  final int position;
  final double playbackRate;
  final bool isPlaying;
  final int playCount;
  final DateTime updatedAt;
  const PlaybackState({
    required this.episodeId,
    required this.position,
    required this.playbackRate,
    required this.isPlaying,
    required this.playCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<int>(episodeId);
    map['position'] = Variable<int>(position);
    map['playback_rate'] = Variable<double>(playbackRate);
    map['is_playing'] = Variable<bool>(isPlaying);
    map['play_count'] = Variable<int>(playCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStatesCompanion(
      episodeId: Value(episodeId),
      position: Value(position),
      playbackRate: Value(playbackRate),
      isPlaying: Value(isPlaying),
      playCount: Value(playCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackState(
      episodeId: serializer.fromJson<int>(json['episodeId']),
      position: serializer.fromJson<int>(json['position']),
      playbackRate: serializer.fromJson<double>(json['playbackRate']),
      isPlaying: serializer.fromJson<bool>(json['isPlaying']),
      playCount: serializer.fromJson<int>(json['playCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<int>(episodeId),
      'position': serializer.toJson<int>(position),
      'playbackRate': serializer.toJson<double>(playbackRate),
      'isPlaying': serializer.toJson<bool>(isPlaying),
      'playCount': serializer.toJson<int>(playCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackState copyWith({
    int? episodeId,
    int? position,
    double? playbackRate,
    bool? isPlaying,
    int? playCount,
    DateTime? updatedAt,
  }) => PlaybackState(
    episodeId: episodeId ?? this.episodeId,
    position: position ?? this.position,
    playbackRate: playbackRate ?? this.playbackRate,
    isPlaying: isPlaying ?? this.isPlaying,
    playCount: playCount ?? this.playCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackState copyWithCompanion(PlaybackStatesCompanion data) {
    return PlaybackState(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      position: data.position.present ? data.position.value : this.position,
      playbackRate: data.playbackRate.present
          ? data.playbackRate.value
          : this.playbackRate,
      isPlaying: data.isPlaying.present ? data.isPlaying.value : this.isPlaying,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackState(')
          ..write('episodeId: $episodeId, ')
          ..write('position: $position, ')
          ..write('playbackRate: $playbackRate, ')
          ..write('isPlaying: $isPlaying, ')
          ..write('playCount: $playCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    episodeId,
    position,
    playbackRate,
    isPlaying,
    playCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackState &&
          other.episodeId == this.episodeId &&
          other.position == this.position &&
          other.playbackRate == this.playbackRate &&
          other.isPlaying == this.isPlaying &&
          other.playCount == this.playCount &&
          other.updatedAt == this.updatedAt);
}

class PlaybackStatesCompanion extends UpdateCompanion<PlaybackState> {
  final Value<int> episodeId;
  final Value<int> position;
  final Value<double> playbackRate;
  final Value<bool> isPlaying;
  final Value<int> playCount;
  final Value<DateTime> updatedAt;
  const PlaybackStatesCompanion({
    this.episodeId = const Value.absent(),
    this.position = const Value.absent(),
    this.playbackRate = const Value.absent(),
    this.isPlaying = const Value.absent(),
    this.playCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackStatesCompanion.insert({
    this.episodeId = const Value.absent(),
    this.position = const Value.absent(),
    this.playbackRate = const Value.absent(),
    this.isPlaying = const Value.absent(),
    this.playCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<PlaybackState> custom({
    Expression<int>? episodeId,
    Expression<int>? position,
    Expression<double>? playbackRate,
    Expression<bool>? isPlaying,
    Expression<int>? playCount,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (position != null) 'position': position,
      if (playbackRate != null) 'playback_rate': playbackRate,
      if (isPlaying != null) 'is_playing': isPlaying,
      if (playCount != null) 'play_count': playCount,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackStatesCompanion copyWith({
    Value<int>? episodeId,
    Value<int>? position,
    Value<double>? playbackRate,
    Value<bool>? isPlaying,
    Value<int>? playCount,
    Value<DateTime>? updatedAt,
  }) {
    return PlaybackStatesCompanion(
      episodeId: episodeId ?? this.episodeId,
      position: position ?? this.position,
      playbackRate: playbackRate ?? this.playbackRate,
      isPlaying: isPlaying ?? this.isPlaying,
      playCount: playCount ?? this.playCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (playbackRate.present) {
      map['playback_rate'] = Variable<double>(playbackRate.value);
    }
    if (isPlaying.present) {
      map['is_playing'] = Variable<bool>(isPlaying.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStatesCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('position: $position, ')
          ..write('playbackRate: $playbackRate, ')
          ..write('isPlaying: $isPlaying, ')
          ..write('playCount: $playCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $QueueItemsTable extends QueueItems
    with TableInfo<$QueueItemsTable, QueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [episodeId, position, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeId};
  @override
  QueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueItem(
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $QueueItemsTable createAlias(String alias) {
    return $QueueItemsTable(attachedDatabase, alias);
  }
}

class QueueItem extends DataClass implements Insertable<QueueItem> {
  final int episodeId;
  final int position;
  final DateTime addedAt;
  const QueueItem({
    required this.episodeId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_id'] = Variable<int>(episodeId);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  QueueItemsCompanion toCompanion(bool nullToAbsent) {
    return QueueItemsCompanion(
      episodeId: Value(episodeId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory QueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueItem(
      episodeId: serializer.fromJson<int>(json['episodeId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeId': serializer.toJson<int>(episodeId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  QueueItem copyWith({int? episodeId, int? position, DateTime? addedAt}) =>
      QueueItem(
        episodeId: episodeId ?? this.episodeId,
        position: position ?? this.position,
        addedAt: addedAt ?? this.addedAt,
      );
  QueueItem copyWithCompanion(QueueItemsCompanion data) {
    return QueueItem(
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueItem(')
          ..write('episodeId: $episodeId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(episodeId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueItem &&
          other.episodeId == this.episodeId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class QueueItemsCompanion extends UpdateCompanion<QueueItem> {
  final Value<int> episodeId;
  final Value<int> position;
  final Value<DateTime> addedAt;
  const QueueItemsCompanion({
    this.episodeId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  QueueItemsCompanion.insert({
    this.episodeId = const Value.absent(),
    required int position,
    this.addedAt = const Value.absent(),
  }) : position = Value(position);
  static Insertable<QueueItem> custom({
    Expression<int>? episodeId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (episodeId != null) 'episode_id': episodeId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  QueueItemsCompanion copyWith({
    Value<int>? episodeId,
    Value<int>? position,
    Value<DateTime>? addedAt,
  }) {
    return QueueItemsCompanion(
      episodeId: episodeId ?? this.episodeId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueItemsCompanion(')
          ..write('episodeId: $episodeId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsEntriesTable extends SettingsEntries
    with TableInfo<$SettingsEntriesTable, SettingsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsEntriesTable createAlias(String alias) {
    return $SettingsEntriesTable(attachedDatabase, alias);
  }
}

class SettingsEntry extends DataClass implements Insertable<SettingsEntry> {
  final String key;
  final String value;
  const SettingsEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsEntriesCompanion toCompanion(bool nullToAbsent) {
    return SettingsEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory SettingsEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingsEntry copyWith({String? key, String? value}) =>
      SettingsEntry(key: key ?? this.key, value: value ?? this.value);
  SettingsEntry copyWithCompanion(SettingsEntriesCompanion data) {
    return SettingsEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsEntriesCompanion extends UpdateCompanion<SettingsEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingsEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $EpisodesCacheTable episodesCache = $EpisodesCacheTable(this);
  late final $ResponseCacheTable responseCache = $ResponseCacheTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $QueueItemsTable queueItems = $QueueItemsTable(this);
  late final $SettingsEntriesTable settingsEntries = $SettingsEntriesTable(
    this,
  );
  late final DownloadDao downloadDao = DownloadDao(this as AppDatabase);
  late final EpisodeCacheDao episodeCacheDao = EpisodeCacheDao(
    this as AppDatabase,
  );
  late final ResponseCacheDao responseCacheDao = ResponseCacheDao(
    this as AppDatabase,
  );
  late final PlaybackDao playbackDao = PlaybackDao(this as AppDatabase);
  late final QueueDao queueDao = QueueDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloadTasks,
    episodesCache,
    responseCache,
    playbackStates,
    queueItems,
    settingsEntries,
  ];
}

typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<int> id,
      required int episodeId,
      required String audioUrl,
      Value<String?> localPath,
      Value<DownloadStatus> status,
      Value<double> progress,
      Value<int?> fileSize,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<int> id,
      Value<int> episodeId,
      Value<String> audioUrl,
      Value<String?> localPath,
      Value<DownloadStatus> status,
      Value<double> progress,
      Value<int?> fileSize,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
    });

class $$DownloadTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTable,
          DownloadTask,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (
            DownloadTask,
            BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask>,
          ),
          DownloadTask,
          PrefetchHooks Function()
        > {
  $$DownloadTasksTableTableManager(_$AppDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> episodeId = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadTasksCompanion(
                id: id,
                episodeId: episodeId,
                audioUrl: audioUrl,
                localPath: localPath,
                status: status,
                progress: progress,
                fileSize: fileSize,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int episodeId,
                required String audioUrl,
                Value<String?> localPath = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                id: id,
                episodeId: episodeId,
                audioUrl: audioUrl,
                localPath: localPath,
                status: status,
                progress: progress,
                fileSize: fileSize,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTable,
      DownloadTask,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (
        DownloadTask,
        BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask>,
      ),
      DownloadTask,
      PrefetchHooks Function()
    >;
typedef $$EpisodesCacheTableCreateCompanionBuilder =
    EpisodesCacheCompanion Function({
      Value<int> id,
      required int subscriptionId,
      required String title,
      required String audioUrl,
      Value<String?> imageUrl,
      Value<int?> audioDuration,
      Value<String?> subscriptionTitle,
      Value<String?> subscriptionImageUrl,
      required DateTime publishedAt,
      required DateTime updatedAt,
      Value<String?> description,
      Value<String?> aiSummary,
    });
typedef $$EpisodesCacheTableUpdateCompanionBuilder =
    EpisodesCacheCompanion Function({
      Value<int> id,
      Value<int> subscriptionId,
      Value<String> title,
      Value<String> audioUrl,
      Value<String?> imageUrl,
      Value<int?> audioDuration,
      Value<String?> subscriptionTitle,
      Value<String?> subscriptionImageUrl,
      Value<DateTime> publishedAt,
      Value<DateTime> updatedAt,
      Value<String?> description,
      Value<String?> aiSummary,
    });

class $$EpisodesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesCacheTable> {
  $$EpisodesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subscriptionId => $composableBuilder(
    column: $table.subscriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subscriptionTitle => $composableBuilder(
    column: $table.subscriptionTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subscriptionImageUrl => $composableBuilder(
    column: $table.subscriptionImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiSummary => $composableBuilder(
    column: $table.aiSummary,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesCacheTable> {
  $$EpisodesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subscriptionId => $composableBuilder(
    column: $table.subscriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subscriptionTitle => $composableBuilder(
    column: $table.subscriptionTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subscriptionImageUrl => $composableBuilder(
    column: $table.subscriptionImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiSummary => $composableBuilder(
    column: $table.aiSummary,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesCacheTable> {
  $$EpisodesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subscriptionId => $composableBuilder(
    column: $table.subscriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subscriptionTitle => $composableBuilder(
    column: $table.subscriptionTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subscriptionImageUrl => $composableBuilder(
    column: $table.subscriptionImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiSummary =>
      $composableBuilder(column: $table.aiSummary, builder: (column) => column);
}

class $$EpisodesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesCacheTable,
          EpisodesCacheData,
          $$EpisodesCacheTableFilterComposer,
          $$EpisodesCacheTableOrderingComposer,
          $$EpisodesCacheTableAnnotationComposer,
          $$EpisodesCacheTableCreateCompanionBuilder,
          $$EpisodesCacheTableUpdateCompanionBuilder,
          (
            EpisodesCacheData,
            BaseReferences<
              _$AppDatabase,
              $EpisodesCacheTable,
              EpisodesCacheData
            >,
          ),
          EpisodesCacheData,
          PrefetchHooks Function()
        > {
  $$EpisodesCacheTableTableManager(_$AppDatabase db, $EpisodesCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subscriptionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int?> audioDuration = const Value.absent(),
                Value<String?> subscriptionTitle = const Value.absent(),
                Value<String?> subscriptionImageUrl = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> aiSummary = const Value.absent(),
              }) => EpisodesCacheCompanion(
                id: id,
                subscriptionId: subscriptionId,
                title: title,
                audioUrl: audioUrl,
                imageUrl: imageUrl,
                audioDuration: audioDuration,
                subscriptionTitle: subscriptionTitle,
                subscriptionImageUrl: subscriptionImageUrl,
                publishedAt: publishedAt,
                updatedAt: updatedAt,
                description: description,
                aiSummary: aiSummary,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subscriptionId,
                required String title,
                required String audioUrl,
                Value<String?> imageUrl = const Value.absent(),
                Value<int?> audioDuration = const Value.absent(),
                Value<String?> subscriptionTitle = const Value.absent(),
                Value<String?> subscriptionImageUrl = const Value.absent(),
                required DateTime publishedAt,
                required DateTime updatedAt,
                Value<String?> description = const Value.absent(),
                Value<String?> aiSummary = const Value.absent(),
              }) => EpisodesCacheCompanion.insert(
                id: id,
                subscriptionId: subscriptionId,
                title: title,
                audioUrl: audioUrl,
                imageUrl: imageUrl,
                audioDuration: audioDuration,
                subscriptionTitle: subscriptionTitle,
                subscriptionImageUrl: subscriptionImageUrl,
                publishedAt: publishedAt,
                updatedAt: updatedAt,
                description: description,
                aiSummary: aiSummary,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpisodesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesCacheTable,
      EpisodesCacheData,
      $$EpisodesCacheTableFilterComposer,
      $$EpisodesCacheTableOrderingComposer,
      $$EpisodesCacheTableAnnotationComposer,
      $$EpisodesCacheTableCreateCompanionBuilder,
      $$EpisodesCacheTableUpdateCompanionBuilder,
      (
        EpisodesCacheData,
        BaseReferences<_$AppDatabase, $EpisodesCacheTable, EpisodesCacheData>,
      ),
      EpisodesCacheData,
      PrefetchHooks Function()
    >;
typedef $$ResponseCacheTableCreateCompanionBuilder =
    ResponseCacheCompanion Function({
      required String key,
      required String payload,
      Value<DateTime> cachedAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$ResponseCacheTableUpdateCompanionBuilder =
    ResponseCacheCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<DateTime> cachedAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$ResponseCacheTableFilterComposer
    extends Composer<_$AppDatabase, $ResponseCacheTable> {
  $$ResponseCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResponseCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $ResponseCacheTable> {
  $$ResponseCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResponseCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResponseCacheTable> {
  $$ResponseCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$ResponseCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResponseCacheTable,
          ResponseCacheData,
          $$ResponseCacheTableFilterComposer,
          $$ResponseCacheTableOrderingComposer,
          $$ResponseCacheTableAnnotationComposer,
          $$ResponseCacheTableCreateCompanionBuilder,
          $$ResponseCacheTableUpdateCompanionBuilder,
          (
            ResponseCacheData,
            BaseReferences<
              _$AppDatabase,
              $ResponseCacheTable,
              ResponseCacheData
            >,
          ),
          ResponseCacheData,
          PrefetchHooks Function()
        > {
  $$ResponseCacheTableTableManager(_$AppDatabase db, $ResponseCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResponseCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResponseCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResponseCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResponseCacheCompanion(
                key: key,
                payload: payload,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                Value<DateTime> cachedAt = const Value.absent(),
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => ResponseCacheCompanion.insert(
                key: key,
                payload: payload,
                cachedAt: cachedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResponseCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResponseCacheTable,
      ResponseCacheData,
      $$ResponseCacheTableFilterComposer,
      $$ResponseCacheTableOrderingComposer,
      $$ResponseCacheTableAnnotationComposer,
      $$ResponseCacheTableCreateCompanionBuilder,
      $$ResponseCacheTableUpdateCompanionBuilder,
      (
        ResponseCacheData,
        BaseReferences<_$AppDatabase, $ResponseCacheTable, ResponseCacheData>,
      ),
      ResponseCacheData,
      PrefetchHooks Function()
    >;
typedef $$PlaybackStatesTableCreateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> episodeId,
      Value<int> position,
      Value<double> playbackRate,
      Value<bool> isPlaying,
      Value<int> playCount,
      Value<DateTime> updatedAt,
    });
typedef $$PlaybackStatesTableUpdateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> episodeId,
      Value<int> position,
      Value<double> playbackRate,
      Value<bool> isPlaying,
      Value<int> playCount,
      Value<DateTime> updatedAt,
    });

class $$PlaybackStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get playbackRate => $composableBuilder(
    column: $table.playbackRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlaying => $composableBuilder(
    column: $table.isPlaying,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get playbackRate => $composableBuilder(
    column: $table.playbackRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlaying => $composableBuilder(
    column: $table.isPlaying,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<double> get playbackRate => $composableBuilder(
    column: $table.playbackRate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPlaying =>
      $composableBuilder(column: $table.isPlaying, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackStatesTable,
          PlaybackState,
          $$PlaybackStatesTableFilterComposer,
          $$PlaybackStatesTableOrderingComposer,
          $$PlaybackStatesTableAnnotationComposer,
          $$PlaybackStatesTableCreateCompanionBuilder,
          $$PlaybackStatesTableUpdateCompanionBuilder,
          (
            PlaybackState,
            BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackState>,
          ),
          PlaybackState,
          PrefetchHooks Function()
        > {
  $$PlaybackStatesTableTableManager(
    _$AppDatabase db,
    $PlaybackStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<double> playbackRate = const Value.absent(),
                Value<bool> isPlaying = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaybackStatesCompanion(
                episodeId: episodeId,
                position: position,
                playbackRate: playbackRate,
                isPlaying: isPlaying,
                playCount: playCount,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<double> playbackRate = const Value.absent(),
                Value<bool> isPlaying = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaybackStatesCompanion.insert(
                episodeId: episodeId,
                position: position,
                playbackRate: playbackRate,
                isPlaying: isPlaying,
                playCount: playCount,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackStatesTable,
      PlaybackState,
      $$PlaybackStatesTableFilterComposer,
      $$PlaybackStatesTableOrderingComposer,
      $$PlaybackStatesTableAnnotationComposer,
      $$PlaybackStatesTableCreateCompanionBuilder,
      $$PlaybackStatesTableUpdateCompanionBuilder,
      (
        PlaybackState,
        BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackState>,
      ),
      PlaybackState,
      PrefetchHooks Function()
    >;
typedef $$QueueItemsTableCreateCompanionBuilder =
    QueueItemsCompanion Function({
      Value<int> episodeId,
      required int position,
      Value<DateTime> addedAt,
    });
typedef $$QueueItemsTableUpdateCompanionBuilder =
    QueueItemsCompanion Function({
      Value<int> episodeId,
      Value<int> position,
      Value<DateTime> addedAt,
    });

class $$QueueItemsTableFilterComposer
    extends Composer<_$AppDatabase, $QueueItemsTable> {
  $$QueueItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueItemsTable> {
  $$QueueItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueItemsTable> {
  $$QueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$QueueItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueItemsTable,
          QueueItem,
          $$QueueItemsTableFilterComposer,
          $$QueueItemsTableOrderingComposer,
          $$QueueItemsTableAnnotationComposer,
          $$QueueItemsTableCreateCompanionBuilder,
          $$QueueItemsTableUpdateCompanionBuilder,
          (
            QueueItem,
            BaseReferences<_$AppDatabase, $QueueItemsTable, QueueItem>,
          ),
          QueueItem,
          PrefetchHooks Function()
        > {
  $$QueueItemsTableTableManager(_$AppDatabase db, $QueueItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => QueueItemsCompanion(
                episodeId: episodeId,
                position: position,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> episodeId = const Value.absent(),
                required int position,
                Value<DateTime> addedAt = const Value.absent(),
              }) => QueueItemsCompanion.insert(
                episodeId: episodeId,
                position: position,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueItemsTable,
      QueueItem,
      $$QueueItemsTableFilterComposer,
      $$QueueItemsTableOrderingComposer,
      $$QueueItemsTableAnnotationComposer,
      $$QueueItemsTableCreateCompanionBuilder,
      $$QueueItemsTableUpdateCompanionBuilder,
      (QueueItem, BaseReferences<_$AppDatabase, $QueueItemsTable, QueueItem>),
      QueueItem,
      PrefetchHooks Function()
    >;
typedef $$SettingsEntriesTableCreateCompanionBuilder =
    SettingsEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsEntriesTableUpdateCompanionBuilder =
    SettingsEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsEntriesTable> {
  $$SettingsEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsEntriesTable> {
  $$SettingsEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsEntriesTable> {
  $$SettingsEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsEntriesTable,
          SettingsEntry,
          $$SettingsEntriesTableFilterComposer,
          $$SettingsEntriesTableOrderingComposer,
          $$SettingsEntriesTableAnnotationComposer,
          $$SettingsEntriesTableCreateCompanionBuilder,
          $$SettingsEntriesTableUpdateCompanionBuilder,
          (
            SettingsEntry,
            BaseReferences<_$AppDatabase, $SettingsEntriesTable, SettingsEntry>,
          ),
          SettingsEntry,
          PrefetchHooks Function()
        > {
  $$SettingsEntriesTableTableManager(
    _$AppDatabase db,
    $SettingsEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsEntriesCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsEntriesTable,
      SettingsEntry,
      $$SettingsEntriesTableFilterComposer,
      $$SettingsEntriesTableOrderingComposer,
      $$SettingsEntriesTableAnnotationComposer,
      $$SettingsEntriesTableCreateCompanionBuilder,
      $$SettingsEntriesTableUpdateCompanionBuilder,
      (
        SettingsEntry,
        BaseReferences<_$AppDatabase, $SettingsEntriesTable, SettingsEntry>,
      ),
      SettingsEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$EpisodesCacheTableTableManager get episodesCache =>
      $$EpisodesCacheTableTableManager(_db, _db.episodesCache);
  $$ResponseCacheTableTableManager get responseCache =>
      $$ResponseCacheTableTableManager(_db, _db.responseCache);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$QueueItemsTableTableManager get queueItems =>
      $$QueueItemsTableTableManager(_db, _db.queueItems);
  $$SettingsEntriesTableTableManager get settingsEntries =>
      $$SettingsEntriesTableTableManager(_db, _db.settingsEntries);
}
