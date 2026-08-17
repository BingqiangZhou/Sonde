import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/request_dedup.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

final selectedDailyReportDateProvider =
    NotifierProvider<SelectedDailyReportDateNotifier, DateTime?>(
      SelectedDailyReportDateNotifier.new,
    );
final dailyReportProvider =
    AsyncNotifierProvider<DailyReportNotifier, PodcastDailyReportResponse?>(
      DailyReportNotifier.new,
    );

final dailyReportDatesProvider =
    AsyncNotifierProvider<
      DailyReportDatesNotifier,
      PodcastDailyReportDatesResponse?
    >(DailyReportDatesNotifier.new);

class SelectedDailyReportDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setDate(DateTime? value) {
    state = value;
  }
}

class DailyReportNotifier extends AsyncNotifier<PodcastDailyReportResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  DateTime? _lastDate;
  final InFlightSlot<PodcastDailyReportResponse?> _loadSlot =
      InFlightSlot<PodcastDailyReportResponse?>();
  final InFlightSlot<PodcastDailyReportResponse?> _generateSlot =
      InFlightSlot<PodcastDailyReportResponse?>();
  final FreshnessTracker _freshness = FreshnessTracker();

  @override
  FutureOr<PodcastDailyReportResponse?> build() {
    return null;
  }

  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    final previousData = state.value;
    if (!forceRefresh &&
        previousData != null &&
        TimeFormatter.sameDate(_lastDate, date) &&
        _freshness.isFresh) {
      return previousData;
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null && TimeFormatter.sameDate(_lastDate, date)) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        final data = await _repository.getDailyReport(date: date);
        _freshness.markSuccess();
        _lastDate = date;
        state = AsyncValue.data(data);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load daily report: $error');
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        return previousData;
      }
    });
  }

  Future<PodcastDailyReportResponse?> generate({
    DateTime? date,
    bool rebuild = false,
  }) async {
    final previousData = state.value;
    final inFlight = _generateSlot.inFlight;
    if (inFlight != null && TimeFormatter.sameDate(_lastDate, date)) {
      return inFlight;
    }

    return _generateSlot(() async {
      try {
        final data = await _repository.generateDailyReport(
          date: date,
          rebuild: rebuild,
        );
        _freshness.markSuccess();
        _lastDate = date;
        state = AsyncValue.data(data);
        await ref
            .read(dailyReportDatesProvider.notifier)
            .load(forceRefresh: true);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to generate daily report: $error');
        if (error is AuthException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        rethrow;
      }
    });
  }
}

class DailyReportDatesNotifier
    extends AsyncNotifier<PodcastDailyReportDatesResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  int _lastSize = _defaultPageSize;
  int _nextPage = 1;
  int _totalPages = 0;
  int _total = 0;
  final Map<String, PodcastDailyReportDateItem> _datesByKey =
      <String, PodcastDailyReportDateItem>{};
  final InFlightSlot<PodcastDailyReportDatesResponse?> _loadSlot =
      InFlightSlot<PodcastDailyReportDatesResponse?>();
  final InFlightSlot<PodcastDailyReportDatesResponse?> _coverageSlot =
      InFlightSlot<PodcastDailyReportDatesResponse?>();
  final FreshnessTracker _freshness = FreshnessTracker();

  static const int _defaultPageSize = 100;

  @override
  FutureOr<PodcastDailyReportDatesResponse?> build() {
    return null;
  }

  DateTime _toDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime value) {
    final normalized = _toDateOnly(value);
    return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  DateTime? _earliestLoadedDate() {
    DateTime? earliest;
    for (final item in _datesByKey.values) {
      final date = _toDateOnly(item.reportDate);
      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }
    return earliest;
  }

  bool _canLoadNextPage() {
    if (_totalPages <= 0) {
      return false;
    }
    return _nextPage <= _totalPages;
  }

  bool _isMonthCovered(DateTime focusedMonth) {
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month);
    final earliest = _earliestLoadedDate();
    if (earliest == null) {
      return false;
    }
    return !earliest.isAfter(monthStart);
  }

  void _resetAggregation() {
    _datesByKey.clear();
    _nextPage = 1;
    _totalPages = 0;
    _total = 0;
  }

  PodcastDailyReportDatesResponse _buildAggregatedResponse() {
    final merged = _datesByKey.values.toList()
      ..sort((left, right) => right.reportDate.compareTo(left.reportDate));
    return PodcastDailyReportDatesResponse(
      dates: merged,
      total: _total,
      page: 1,
      size: _lastSize,
      pages: _totalPages,
    );
  }

  Future<PodcastDailyReportDatesResponse?> _fetchAndMerge({
    required int page,
    required int size,
  }) async {
    final payload = await _repository.getDailyReportDates(
      page: page,
      size: size,
    );
    for (final item in payload.dates) {
      final normalizedDate = _toDateOnly(item.reportDate);
      _datesByKey[_dateKey(normalizedDate)] = PodcastDailyReportDateItem(
        reportDate: normalizedDate,
        totalItems: item.totalItems,
        generatedAt: item.generatedAt,
      );
    }

    _total = payload.total;
    _totalPages = payload.pages;
    _nextPage = page + 1;
    _lastSize = size;
    _freshness.markSuccess();

    final merged = _buildAggregatedResponse();
    state = AsyncValue.data(merged);
    return merged;
  }

  Future<PodcastDailyReportDatesResponse?> load({
    int page = 1,
    int size = _defaultPageSize,
    bool forceRefresh = false,
  }) async {
    final previousData = state.value;
    final isFirstPageQuery = page == 1;
    if (!forceRefresh &&
        previousData != null &&
        isFirstPageQuery &&
        _freshness.isFresh) {
      return previousData;
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null && isFirstPageQuery) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        if (forceRefresh || isFirstPageQuery) {
          _resetAggregation();
        }
        return await _fetchAndMerge(page: page, size: size);
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load daily report dates: $error');
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        return previousData;
      }
    });
  }

  Future<PodcastDailyReportDatesResponse?> ensureMonthCoverage(
    DateTime focusedMonth,
  ) async {
    final normalizedMonth = DateTime(focusedMonth.year, focusedMonth.month);
    if (_datesByKey.isEmpty) {
      await load();
    }
    if (_isMonthCovered(normalizedMonth) || !_canLoadNextPage()) {
      return state.value;
    }

    final inFlightCoverage = _coverageSlot.inFlight;
    if (inFlightCoverage != null) {
      return inFlightCoverage;
    }

    return _coverageSlot(() async {
      try {
        while (!_isMonthCovered(normalizedMonth) && _canLoadNextPage()) {
          await _fetchAndMerge(page: _nextPage, size: _lastSize);
        }
      } catch (error) {
        logger.AppLogger.debug(
          'Failed to ensure daily report date coverage for month=$normalizedMonth error=$error',
        );
      }
      return state.value;
    });
  }
}
