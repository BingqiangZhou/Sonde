import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

/// Behavior tests for ConversationNotifier: optimistic send, failure
/// rollback, session switching, and new-session assignment.
void main() {
  late _FakeConversationRepository repository;

  /// Returns a container with the episode-1 conversation provider kept
  /// alive (autoDispose families lose state without an active listener).
  (ProviderContainer, ConversationNotifier) createConversation() {
    final container = ProviderContainer(
      overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(conversationProvider(1), (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(conversationProvider(1).notifier);
    return (container, notifier);
  }

  setUp(() {
    repository = _FakeConversationRepository();
  });

  PodcastConversationMessage message({
    required int id,
    required String role,
    required String content,
    int turn = 0,
  }) {
    return PodcastConversationMessage(
      id: id,
      role: role,
      content: content,
      conversationTurn: turn,
      createdAt: '2026-01-01T00:00:00Z',
    );
  }

  group('ConversationNotifier.sendMessage', () {
    test('appends optimistic user message and replaces with server history',
        () async {
      repository.historyBySession[5] = [
        message(id: 1, role: 'user', content: 'hello'),
        message(id: 2, role: 'assistant', content: 'hi there', turn: 1),
      ];
      final (container, notifier) = createConversation();
      container
          .read(currentSessionIdProvider(1).notifier)
          .set(5);
      await Future<void>.delayed(Duration.zero);

      // Prime the response for after the send.
      repository.historyBySession[5] = [
        message(id: 1, role: 'user', content: 'hello'),
        message(id: 2, role: 'assistant', content: 'hi there', turn: 1),
        message(id: 3, role: 'user', content: 'more?', turn: 2),
        message(id: 4, role: 'assistant', content: 'sure', turn: 3),
      ];

      final sendFuture = notifier.sendMessage('more?');
      final midFlight = container.read(conversationProvider(1));
      expect(midFlight.isSending, isTrue);
      expect(midFlight.messages.last.id, isNegative);
      expect(midFlight.messages.last.content, 'more?');

      await sendFuture;

      final state = container.read(conversationProvider(1));
      expect(state.isSending, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.messages, hasLength(4));
      expect(state.messages.every((m) => m.id > 0), isTrue,
          reason: 'optimistic negative-id message must be replaced');
      expect(repository.sendRequests.single.message, 'more?');
      expect(repository.sendRequests.single.sessionId, 5);
    });

    test('rolls back optimistic message and surfaces readable error',
        () async {
      final (container, notifier) = createConversation();
      container
          .read(currentSessionIdProvider(1).notifier)
          .set(5);
      await Future<void>.delayed(Duration.zero);

      repository.sendError =
          const NetworkException('Connection timeout');
      await notifier.sendMessage('will fail');

      final state = container.read(conversationProvider(1));
      expect(state.isSending, isFalse);
      expect(state.messages.every((m) => m.id >= 0), isTrue,
          reason: 'optimistic message must be removed on failure');
      expect(state.errorMessage, 'Connection timeout');
    });

    test('assigns the session id returned for a brand-new conversation',
        () async {
      final (container, notifier) = createConversation();
      // No session selected yet (sessionId null).
      await Future<void>.delayed(Duration.zero);

      final newSessionMessages = [
        message(id: 11, role: 'user', content: 'first'),
        message(id: 12, role: 'assistant', content: 'reply', turn: 1),
      ];
      repository.newSessionHistory = PodcastConversationHistoryResponse(
        episodeId: 1,
        messages: newSessionMessages,
        total: 2,
        sessionId: 7,
      );
      // After the session id is assigned the notifier rebuilds and reloads
      // history for session 7 from the repository.
      repository.historyBySession[7] = newSessionMessages;

      await notifier.sendMessage('first');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentSessionIdProvider(1)), 7);
      final state = container.read(conversationProvider(1));
      expect(state.sessionId, 7);
      expect(state.messages, hasLength(2));
    });
  });

  group('ConversationNotifier session switching', () {
    test('reloads history when the current session id changes', () async {
      repository.historyBySession[5] = [
        message(id: 1, role: 'user', content: 'session five'),
      ];
      repository.historyBySession[6] = [
        message(id: 10, role: 'user', content: 'session six'),
      ];
      final (container, notifier) = createConversation();
      container
          .read(currentSessionIdProvider(1).notifier)
          .set(5);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(conversationProvider(1)).messages.single.content,
          'session five');

      container.read(currentSessionIdProvider(1).notifier).set(6);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationProvider(1));
      expect(state.sessionId, 6);
      expect(state.messages.single.content, 'session six');
    });

    test('switching away mid-load discards the stale session result',
        () async {
      repository.historyBySession[5] = [
        message(id: 1, role: 'user', content: 'slow session'),
      ];
      repository.historyBySession[6] = [
        message(id: 9, role: 'user', content: 'fast session'),
      ];
      final (container, notifier) = createConversation();
      container
          .read(currentSessionIdProvider(1).notifier)
          .set(5);

      // Switch before the first history load completes.
      container.read(currentSessionIdProvider(1).notifier).set(6);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationProvider(1));
      expect(state.sessionId, 6);
      expect(state.messages.single.content, 'fast session');
    });
  });

  group('ConversationNotifier.clearHistory', () {
    test('empties messages on success', () async {
      repository.historyBySession[5] = [
        message(id: 1, role: 'user', content: 'hello'),
      ];
      final (container, notifier) = createConversation();
      container
          .read(currentSessionIdProvider(1).notifier)
          .set(5);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(conversationProvider(1)).messages, isNotEmpty);

      await notifier.clearHistory();

      final state = container.read(conversationProvider(1));
      expect(state.messages, isEmpty);
      expect(state.hasError, isFalse);
      expect(repository.clearedSessionIds, [5]);
    });

    test('keeps messages and reports error on failure', () async {
      repository.historyBySession[5] = [
        message(id: 1, role: 'user', content: 'hello'),
      ];
      repository.clearError = const ServerException('boom');
      final (container, notifier) = createConversation();
      container
          .read(currentSessionIdProvider(1).notifier)
          .set(5);
      await Future<void>.delayed(Duration.zero);

      await notifier.clearHistory();

      final state = container.read(conversationProvider(1));
      expect(state.messages, isNotEmpty);
      expect(state.errorMessage, 'boom');
    });
  });
}

class _FakeConversationRepository extends PodcastRepository {
  _FakeConversationRepository() : super(PodcastApiService(Dio()));

  final Map<int, List<PodcastConversationMessage>> historyBySession = {};
  final List<PodcastConversationSendRequest> sendRequests = [];
  final List<int> clearedSessionIds = [];
  PodcastConversationHistoryResponse? newSessionHistory;
  Exception? sendError;
  Exception? clearError;

  @override
  Future<ConversationSessionListResponse> getConversationSessions({
    required int episodeId,
  }) async {
    return const ConversationSessionListResponse(sessions: [], total: 0);
  }

  @override
  Future<PodcastConversationHistoryResponse> getConversationHistory({
    required int episodeId,
    int limit = 100,
    int? sessionId,
  }) async {
    if (sessionId == null && newSessionHistory != null) {
      return newSessionHistory!;
    }
    return PodcastConversationHistoryResponse(
      episodeId: episodeId,
      messages: historyBySession[sessionId] ?? [],
      total: historyBySession[sessionId]?.length ?? 0,
      sessionId: sessionId,
    );
  }

  @override
  Future<PodcastConversationSendResponse> sendConversationMessage({
    required int episodeId,
    required PodcastConversationSendRequest request,
  }) async {
    sendRequests.add(request);
    final error = sendError;
    if (error != null) throw error;
    return const PodcastConversationSendResponse(
      id: 99,
      role: 'assistant',
      content: 'ok',
      conversationTurn: 1,
      createdAt: '2026-01-01T00:00:00Z',
    );
  }

  @override
  Future<PodcastConversationClearResponse> clearConversationHistory({
    required int episodeId,
    int? sessionId,
  }) async {
    final error = clearError;
    if (error != null) throw error;
    clearedSessionIds.add(sessionId ?? -1);
    return PodcastConversationClearResponse(
      episodeId: episodeId,
      deletedCount: 0,
    );
  }
}
