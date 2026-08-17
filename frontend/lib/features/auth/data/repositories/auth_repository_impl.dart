import 'package:dio/dio.dart';
import 'package:sonde/core/network/dio_client.dart';
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/storage/secure_storage_service.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;
import 'package:sonde/features/auth/domain/models/auth_request.dart';
import 'package:sonde/features/auth/domain/models/auth_response.dart';
import 'package:sonde/features/auth/domain/models/user.dart';
import 'package:sonde/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {

  AuthRepositoryImpl(
    this._apiClient,
    this._secureStorage,
  );
  final DioClient _apiClient;
  final SecureStorageService _secureStorage;

  /// Persists the access and refresh tokens from [authResponse].
  Future<void> _persistTokens(AuthResponse authResponse) async {
    await _secureStorage.saveAccessToken(authResponse.accessToken);
    await _secureStorage.saveRefreshToken(authResponse.refreshToken);
  }

  /// Runs [action], mapping Dio and unexpected errors to [AppException]s.
  ///
  /// When [onError] is given it is awaited on every catch path before the
  /// mapped exception is thrown (used by [logout] to clear stored tokens).
  Future<T> _guard<T>(
    Future<T> Function() action, {
    Future<void> Function()? onError,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      await onError?.call();
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      await onError?.call();
      rethrow;
    } catch (e) {
      await onError?.call();
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<AuthResponse> login(LoginRequest request) {
    return _guard(() async {
      final response = await _apiClient.post(
        '/auth/login',
        data: request.toJson(),
      );
      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

      await _persistTokens(authResponse);

      return authResponse;
    });
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) {
    return _guard(() async {
      final response = await _apiClient.post(
        '/auth/register',
        data: request.toJson(),
      );

      final responseData = response.data as Map<String, dynamic>;

      AuthResponse authResponse;

      if (responseData.containsKey('id') &&
          responseData.containsKey('email') &&
          !responseData.containsKey('access_token')) {
        logger.AppLogger.debug('Received User object instead of Token, attempting login...');
        authResponse = await _loginInternal(request.email, request.password);
      } else {
        authResponse = AuthResponse.fromJson(responseData);
      }

      await _persistTokens(authResponse);

      return authResponse;
    });
  }

  Future<AuthResponse> _loginInternal(String email, String password) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: LoginRequest(username: email, password: password).toJson(),
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) {
    return _guard(() async {
      final response = await _apiClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

      await _persistTokens(authResponse);

      return RefreshTokenResponse(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        tokenType: authResponse.tokenType,
        expiresIn: authResponse.expiresIn,
        expiresAt: authResponse.expiresAt,
        serverTime: authResponse.serverTime,
      );
    });
  }

  @override
  Future<void> logout(String? refreshToken) {
    return _guard(
      () async {
        final token = refreshToken ?? await _secureStorage.getRefreshToken();

        if (token != null && token.isNotEmpty) {
          await _apiClient.post(
            '/auth/logout',
            data: {'refresh_token': token},
          );
        }

        await _secureStorage.clearTokens();
      },
      onError: _secureStorage.clearTokens,
    );
  }

  @override
  Future<User> getCurrentUser() {
    return _guard(() async {
      final response = await _apiClient.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    });
  }

  @override
  Future<User> updateProfile(String username) {
    return _guard(() async {
      final response = await _apiClient.patch(
        '/auth/me',
        data: {'username': username},
      );
      return User.fromJson(response.data as Map<String, dynamic>);
    });
  }

  @override
  Future<void> forgotPassword(ForgotPasswordRequest request) {
    return _guard(() async {
      await _apiClient.post(
        '/auth/forgot-password',
        data: request.toJson(),
      );
    });
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) {
    return _guard(() async {
      await _apiClient.post(
        '/auth/reset-password',
        data: request.toJson(),
      );
    });
  }
}
