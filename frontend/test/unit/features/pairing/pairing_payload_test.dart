import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/pairing/domain/pairing_payload.dart';

void main() {
  group('PairingPayload.tryParse', () {
    test('parses the sonde://connect QR payload', () {
      final payload = PairingPayload.tryParse(
        'sonde://connect?host=http%3A%2F%2F192.168.1.5%3A8000&key=sk-abc123',
      );
      expect(payload, isNotNull);
      expect(payload!.host, 'http://192.168.1.5:8000');
      expect(payload.apiKey, 'sk-abc123');
    });

    test('parses the host|key manual form', () {
      final payload = PairingPayload.tryParse('http://10.0.0.2:8000|my-key');
      expect(payload, isNotNull);
      expect(payload!.host, 'http://10.0.0.2:8000');
      expect(payload.apiKey, 'my-key');
    });

    test('normalizes host: adds scheme, strips trailing slash and api suffix', () {
      final payload = PairingPayload.tryParse(
        'sonde://connect?host=192.168.1.5%3A8000%2Fapi%2Fv1%2F&key=k',
      );
      expect(payload, isNotNull);
      expect(payload!.host, 'http://192.168.1.5:8000');
    });

    test('rejects missing key', () {
      expect(
        PairingPayload.tryParse('sonde://connect?host=http%3A%2F%2Fx'),
        isNull,
      );
    });

    test('rejects missing host', () {
      expect(PairingPayload.tryParse('sonde://connect?key=k'), isNull);
    });

    test('rejects foreign sonde deep links', () {
      expect(PairingPayload.tryParse('sonde://other?host=x&key=k'), isNull);
    });

    test('rejects empty and malformed input', () {
      expect(PairingPayload.tryParse(''), isNull);
      expect(PairingPayload.tryParse('   '), isNull);
      expect(PairingPayload.tryParse('not a payload at all'), isNull);
    });

    test('rejects bare URLs without a key', () {
      expect(PairingPayload.tryParse('http://192.168.1.5:8000'), isNull);
    });
  });
}
