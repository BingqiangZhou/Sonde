import 'package:sonde/features/auth/domain/models/auth_request.dart';
import 'package:sonde/features/auth/domain/models/auth_response.dart';
import 'package:sonde/features/auth/domain/models/user.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<RefreshTokenResponse> refreshToken(String refreshToken);
  Future<void> logout(String? refreshToken);
  Future<User> getCurrentUser();
  Future<User> updateProfile(String username);
  Future<void> forgotPassword(ForgotPasswordRequest request);
  Future<void> resetPassword(ResetPasswordRequest request);
}
