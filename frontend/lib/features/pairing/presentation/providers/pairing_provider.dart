/// Pairing flow: verify a scanned/pasted backend connection and persist it.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/providers/core_providers.dart';
import 'package:sonde/core/storage/secure_storage_service.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/pairing/domain/pairing_payload.dart';

/// Secure-storage key holding the deployment API key.
const kApiKeyStorageKey = 'api_key';

class PairingState {
  const PairingState({
    this.isVerifying = false,
    this.error,
    this.lastVerifiedHost,
  });

  final bool isVerifying;
  final String? error;
  final String? lastVerifiedHost;

  PairingState copyWith({
    bool? isVerifying,
    String? error,
    bool clearError = false,
    String? lastVerifiedHost,
  }) {
    return PairingState(
      isVerifying: isVerifying ?? this.isVerifying,
      error: clearError ? null : (error ?? this.error),
      lastVerifiedHost: lastVerifiedHost ?? this.lastVerifiedHost,
    );
  }
}

class PairingController extends Notifier<PairingState> {
  SecureStorageService get _secureStorage => ref.read(secureStorageProvider);

  @override
  PairingState build() => const PairingState();

  /// Verify [payload] against the backend and persist host + API key.
  ///
  /// A single authenticated request to the sync endpoint proves both
  /// reachability and key validity before anything is stored.
  Future<bool> pair(PairingPayload payload) async {
    state = state.copyWith(isVerifying: true, clearError: true);
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: '${payload.host}/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'X-API-Key': payload.apiKey},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final response = await dio.get<dynamic>(
        '/podcasts/episodes/sync',
        queryParameters: {'limit': 1},
      );
      if (response.statusCode != 200) {
        state = PairingState(
          error: 'HTTP ${response.statusCode}: ${payload.host}',
        );
        return false;
      }

      await ref
          .read(serverConfigProvider.notifier)
          .updateServerUrl(payload.host, clearData: false);
      await _secureStorage.save(kApiKeyStorageKey, payload.apiKey);
      ref.read(authProvider.notifier).markPaired();

      state = PairingState(lastVerifiedHost: payload.host);
      return true;
    } on DioException catch (e) {
      state = PairingState(error: '${e.type.name}: ${e.message}');
      return false;
    } catch (e) {
      state = PairingState(error: e.toString());
      return false;
    }
  }

  /// Whether a pairing (host + API key) is already stored.
  static Future<bool> isPaired(SecureStorageService storage) async {
    final key = await storage.get(kApiKeyStorageKey);
    return key != null && key.isNotEmpty;
  }
}

final pairingProvider = NotifierProvider<PairingController, PairingState>(
  PairingController.new,
);

/// Exposed for the DioClient fallback auth (avoid a provider cycle).
Future<String?> readStoredApiKey(SecureStorageService storage) {
  return storage.get(kApiKeyStorageKey);
}
