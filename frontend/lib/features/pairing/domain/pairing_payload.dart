/// Parsed payload of the `sonde://connect` pairing QR / manual entry.
library;

import 'package:sonde/core/network/server_health_service.dart';

class PairingPayload {
  const PairingPayload({required this.host, required this.apiKey});

  /// Normalized backend origin, e.g. `http://192.168.1.5:8000`
  /// (no trailing slash, no `/api/v1` suffix — the DioClient appends it).
  final String host;

  /// Deployment API key.
  final String apiKey;

  /// Parse raw scanned or pasted text.
  ///
  /// Accepted forms:
  /// - `sonde://connect?host=<encoded>&key=<encoded>` (admin pairing QR)
  /// - `host|key` (manual paste fallback used by desktop pairing)
  ///
  /// Returns `null` for anything malformed.
  static PairingPayload? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'sonde') {
      if (uri.host != 'connect') return null;
      return _build(
        host: uri.queryParameters['host'],
        apiKey: uri.queryParameters['key'],
      );
    }

    final parts = trimmed.split('|');
    if (parts.length == 2) {
      return _build(host: parts[0], apiKey: parts[1]);
    }

    return null;
  }

  static PairingPayload? _build({String? host, String? apiKey}) {
    if (host == null || host.isEmpty) return null;
    if (apiKey == null || apiKey.isEmpty) return null;

    final normalizedHost =
        ServerHealthService.normalizeBaseUrl(host).replaceAll(
          RegExp(r'/+$'),
          '',
        );
    if (!normalizedHost.startsWith('http')) return null;

    return PairingPayload(host: normalizedHost, apiKey: apiKey);
  }
}
