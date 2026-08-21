import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/core/services/episode_sync_service.dart';
import 'package:sonde/core/network/dio_client.dart';

class _FakeDioClient implements DioClient {
  _FakeDioClient(this.pages);

  /// Each entry is the decoded response body for one sync request.
  final List<Map<String, dynamic>> pages;
  final List<Map<String, dynamic>> requests = [];
  int callIndex = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add({'path': path, ...?queryParameters});
    final page = pages[callIndex.clamp(0, pages.length - 1)];
    callIndex++;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: page,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName}');
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, dynamic> item(int id, {String? summary}) => {
        'id': id,
        'subscription_id': 5,
        'title': 'Episode $id',
        'description': 'desc $id',
        'audio_url': 'https://example.com/$id.mp3',
        'audio_duration': 1200,
        'published_at': '2026-08-20T10:00:00Z',
        'updated_at': '2026-08-20T11:00:00Z',
        'subscription_title': 'Test Sub',
        'ai_summary': summary,
      };

  test('pulls pages until has_more is false and persists the cursor',
      () async {
    final dio = _FakeDioClient([
      {
        'items': [item(1), item(2)],
        'has_more': true,
        'next_cursor': 'cursor-1',
      },
      {
        'items': [item(3)],
        'has_more': false,
        'next_cursor': 'cursor-2',
      },
    ]);
    final service = EpisodeSyncService(dio, db);

    final result = await service.sync();

    expect(result.completed, isTrue);
    expect(result.syncedEpisodes, 3);
    // Cursor passed on the second request only.
    expect(dio.requests[0].containsKey('cursor'), isFalse);
    expect(dio.requests[1]['cursor'], 'cursor-1');
    // Watermark persisted for the next incremental run.
    expect(await db.settingsDao.get('episode_sync_cursor'), 'cursor-2');
    // Cache hydrated with summary + description.
    final cached = await db.episodeCacheDao.getById(1);
    expect(cached, isNotNull);
    expect(cached!.description, 'desc 1');
    expect(cached.aiSummary, isNull);
  });

  test('keeps ai_summary for offline rendering', () async {
    final dio = _FakeDioClient([
      {
        'items': [item(9, summary: 'the summary')],
        'has_more': false,
        'next_cursor': 'c9',
      },
    ]);
    final service = EpisodeSyncService(dio, db);

    await service.sync();

    final cached = await db.episodeCacheDao.getById(9);
    expect(cached!.aiSummary, 'the summary');
  });

  test('resumes from the persisted cursor on later runs', () async {
    await db.settingsDao.set('episode_sync_cursor', 'watermark-42');
    final dio = _FakeDioClient([
      {
        'items': [],
        'has_more': false,
        'next_cursor': null,
      },
    ]);
    final service = EpisodeSyncService(dio, db);

    final result = await service.sync();

    expect(dio.requests.first['cursor'], 'watermark-42');
    expect(result.syncedEpisodes, 0);
    expect(result.completed, isTrue);
    // Empty batch with no cursor keeps the previous watermark.
    expect(await db.settingsDao.get('episode_sync_cursor'), 'watermark-42');
  });

  test('upsert updates existing cache rows', () async {
    final first = _FakeDioClient([
      {
        'items': [item(1, summary: 'old')],
        'has_more': false,
        'next_cursor': 'c1',
      },
    ]);
    await EpisodeSyncService(first, db).sync();

    final second = _FakeDioClient([
      {
        'items': [item(1, summary: 'new')],
        'has_more': false,
        'next_cursor': 'c2',
      },
    ]);
    await EpisodeSyncService(second, db).sync();

    final cached = await db.episodeCacheDao.getById(1);
    expect(cached!.aiSummary, 'new');
  });
}
