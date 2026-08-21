/// Pairing session state (server-pipeline phase 4).
///
/// The JWT multi-user flow was removed together with the backend auth
/// domain: the app authenticates exclusively via the deployment API key
/// stored by the QR pairing flow. This notifier tracks whether a pairing
/// exists and clears it on disconnect.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/providers/core_providers.dart';
import 'package:sonde/core/storage/secure_storage_service.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;
import 'package:sonde/features/auth/domain/models/user.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.user,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  /// Always null in pairing mode; kept so list/detail UI keeps compiling
  /// and renders its guest fallbacks.
  final User? user;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    bool clearError = false,
    User? user,
    bool clearUser = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

enum AuthOperation {
  checkAuth,
  disconnect,
}

class AuthNotifier extends Notifier<AuthState> {
  SecureStorageService get _secureStorage => ref.read(secureStorageProvider);

  static const String _apiKeyStorageKey = 'api_key';

  @override
  AuthState build() {
    return const AuthState();
  }

  /// A stored deployment API key (QR pairing) authenticates the session.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    final apiKey = await _secureStorage.get(_apiKeyStorageKey);
    state = state.copyWith(
      isAuthenticated: apiKey != null && apiKey.isNotEmpty,
      isLoading: false,
    );
  }

  /// API-key pairing mode: authenticated without a user profile.
  void markPaired() {
    state = state.copyWith(
      isAuthenticated: true,
      isLoading: false,
      clearError: true,
    );
  }

  void resetLoadingState() {
    state = state.copyWith(isLoading: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Drop the local pairing (called by the profile disconnect dialog and
  /// by server switching); the router then redirects to /pairing.
  Future<void> logout() async {
    await clearLocalAuthState();
    state = state.copyWith(isAuthenticated: false, clearUser: true);
  }

  /// Clear every stored credential without touching navigation state.
  Future<void> clearLocalAuthState() async {
    try {
      await _secureStorage.clearTokens();
      await _secureStorage.remove(_apiKeyStorageKey);
    } catch (e) {
      logger.AppLogger.debug('[Auth] Failed to clear local auth state: $e');
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
