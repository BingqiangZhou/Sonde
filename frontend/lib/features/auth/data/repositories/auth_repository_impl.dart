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

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: request.toJson(),
      );
      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    try {
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

      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<AuthResponse> _loginInternal(String email, String password) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: LoginRequest(username: email, password: password).toJson(),
    );
    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

      await _secureStorage.saveAccessToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);

      return RefreshTokenResponse(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        tokenType: authResponse.tokenType,
        expiresIn: authResponse.expiresIn,
        expiresAt: authResponse.expiresAt,
        serverTime: authResponse.serverTime,
      );
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<void> logout(String? refreshToken) async {
    try {
      final token = refreshToken ?? await _secureStorage.getRefreshToken();

      if (token != null && token.isNotEmpty) {
        await _apiClient.post(
          '/auth/logout',
          data: {'refresh_token': token},
        );
      }

      await _secureStorage.clearTokens();
    } on DioException catch (e) {
      await _secureStorage.clearTokens();
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      await _secureStorage.clearTokens();
      rethrow;
    } catch (e) {
      await _secureStorage.clearTokens();
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    try {
      await _apiClient.post(
        '/auth/forgot-password',
        data: request.toJson(),
      );
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) async {
    try {
      await _apiClient.post(
        '/auth/reset-password',
        data: request.toJson(),
      );
    } on DioException catch (e) {
      if (e.error is AppException) {
        throw e.error! as AppException;
      }
      throw UnknownException(e.message ?? 'Unknown Dio error');
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }
}
