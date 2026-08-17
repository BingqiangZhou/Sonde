import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sonde/core/app/config/app_config.dart' as config;
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/network/token_refresh_service.dart';
import 'package:sonde/core/storage/secure_storage_service.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;
import 'package:sonde/core/utils/url_normalizer.dart';

@immutable
class DioClientInitOptions {
  const DioClientInitOptions({this.initialServerBaseUrl});
  final String? initialServerBaseUrl;
}

class DioClient {

  DioClient({
    DioClientInitOptions initOptions = const DioClientInitOptions(),
    SecureStorageService? secureStorage,
  }) : _secureStorage =
           secureStorage ?? SecureStorageServiceImpl(const FlutterSecureStorage()) {
    _dio = Dio(BaseOptions(
      headers: config.ApiConstants.headers,
      connectTimeout: config.AppConfig.connectionTimeout,
      receiveTimeout: config.AppConfig.receiveTimeout,
      sendTimeout: config.AppConfig.sendTimeout,
    ));
    _tokenRefreshService = TokenRefreshService(
      dio: _dio,
      secureStorage: _secureStorage,
    );
    _cacheOptions = CacheOptions(
      store: MemCacheStore(),
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(hours: 1),
      hitCacheOnErrorCodes: [500],
    );
    _dio.interceptors.addAll([
      DioCacheInterceptor(options: _cacheOptions),
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    ]);
    _initializeBaseUrl(initialServerBaseUrl: initOptions.initialServerBaseUrl);
  }
  static const int _maxRetries = 3;

  late final Dio _dio;
  late final TokenRefreshService _tokenRefreshService;
  late final CacheOptions _cacheOptions;
  final SecureStorageService _secureStorage;
  String? _cachedAccessToken;

  // --- Public API ---------------------------------------------------------

  Dio get dio => _dio;

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
    _log('Base URL updated to: $url');
  }

  // HTTP methods
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get<dynamic>(path, queryParameters: queryParameters);

  Future<Response<dynamic>> post(String path, {dynamic data, bool invalidateCache = false}) =>
      _dio.post(path, data: data, options: _cacheOpts(invalidateCache));

  Future<Response<dynamic>> put(String path, {dynamic data, bool invalidateCache = true}) =>
      _dio.put(path, data: data, options: _cacheOpts(invalidateCache));

  Future<Response<dynamic>> patch(String path, {dynamic data, bool invalidateCache = true}) =>
      _dio.patch(path, data: data, options: _cacheOpts(invalidateCache));

  Future<Response<dynamic>> delete(String path, {bool invalidateCache = true}) =>
      _dio.delete(path, options: _cacheOpts(invalidateCache));

  // Cache & token management
  Future<void> clearCache() async {
    await _cacheOptions.store!.clean();
    _log('All caches cleared');
  }
  void clearETagCache() => clearCache();
  Future<TokenRefreshResult> refreshSessionToken() =>
      _tokenRefreshService.refreshToken();
  void setToken(String? token) {
    _cachedAccessToken = token;
    _log('Token cache ${token != null ? "updated" : "cleared"}');
  }

  void dispose() {
    _cachedAccessToken = null;
    _dio.close(force: true);
    logger.AppLogger.debug('[DioClient] Disposed');
  }

  // --- Interceptors -------------------------------------------------------

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    _log('${options.method} ${options.baseUrl}${options.path}');
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }
    var token = _cachedAccessToken;
    if (token == null) {
      token = await _secureStorage.getAccessToken();
      if (token != null) _cachedAccessToken = token;
    }
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    _log('ERROR ${err.type} ${err.requestOptions.path}');
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        final count = (err.requestOptions.extra['_retryCount'] as int? ?? 0) + 1;
        if (count <= _maxRetries) {
          try {
            await Future<void>.delayed(Duration(seconds: count));
            final response = await _dio.fetch<dynamic>(err.requestOptions.copyWith(
              extra: {...err.requestOptions.extra, '_retryCount': count},
            ));
            handler.resolve(response);
            return;
          } catch (_) { /* fall through */ }
        }
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('Connection timeout'),
        ));
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status == 401) {
          await _handle401(err, handler);
        } else if (status == 403) {
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: DioExceptionType.badResponse,
            error: AuthException.fromDioError(err),
          ));
        } else {
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: DioExceptionType.badResponse,
            error: ServerException.fromDioError(err),
          ));
        }
      default:
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: NetworkException.fromDioError(err),
        ));
    }
  }

  Future<void> _handle401(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final response = await _tokenRefreshService.handle401(
        err.requestOptions,
        onTokenUpdated: (t) => _cachedAccessToken = t,
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.reject(DioException(
        requestOptions: e.requestOptions,
        response: e.response ?? err.response,
        type: DioExceptionType.badResponse,
        error: AuthException.fromDioError(err),
      ));
    } catch (_) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: const NetworkException('Session refresh temporarily unavailable.'),
      ));
    }
  }

  // --- Private helpers ----------------------------------------------------

  void _initializeBaseUrl({String? initialServerBaseUrl}) {
    final raw = initialServerBaseUrl ?? config.AppConfig.defaultServerBaseUrl;
    final normalized = raw.isNotEmpty ? UrlNormalizer.normalize(raw) : '';
    final base = normalized.isNotEmpty
        ? '$normalized/api/v1'
        : '${config.AppConfig.defaultServerBaseUrl}/api/v1';
    _dio.options.baseUrl = base;
    _log('Initialized with baseUrl: $base');
  }

  Options? _cacheOpts(bool invalidate) {
    if (!invalidate) return null;
    return Options(
      extra: {'cacheOptions': _cacheOptions.copyWith(policy: CachePolicy.refresh)},
    );
  }

  void _log(String message) {
    if (kDebugMode) logger.AppLogger.debug('[DioClient] $message');
  }
}
