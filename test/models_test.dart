import 'package:flutter_test/flutter_test.dart';
import 'package:wireguard_dart/src/models/models.dart';

void main() {
  group('ConnectionStatus.fromString', () {
    test('maps every state the native side reports', () {
      expect(ConnectionStatus.fromString('connecting'), ConnectionStatus.connecting);
      expect(ConnectionStatus.fromString('connected'), ConnectionStatus.connected);
      expect(ConnectionStatus.fromString('disconnecting'), ConnectionStatus.disconnecting);
      expect(ConnectionStatus.fromString('disconnected'), ConnectionStatus.disconnected);
      expect(ConnectionStatus.fromString('unknown'), ConnectionStatus.unknown);
    });

    test('falls back to unknown rather than throwing on anything else', () {
      expect(ConnectionStatus.fromString(''), ConnectionStatus.unknown);
      expect(ConnectionStatus.fromString('CONNECTED'), ConnectionStatus.unknown);
      expect(ConnectionStatus.fromString('reasserting'), ConnectionStatus.unknown);
    });
  });

  group('NotificationPermission.fromString', () {
    test('maps the values Android sends, ignoring case', () {
      expect(NotificationPermission.fromString('GRANTED'), NotificationPermission.granted);
      expect(NotificationPermission.fromString('granted'), NotificationPermission.granted);
      expect(NotificationPermission.fromString('DENIED'), NotificationPermission.denied);
      expect(
        NotificationPermission.fromString('PERMANENTLY_DENIED'),
        NotificationPermission.permanentlyDenied,
      );
    });

    test('defaults to denied for null and anything unrecognised', () {
      expect(NotificationPermission.fromString(null), NotificationPermission.denied);
      expect(NotificationPermission.fromString(''), NotificationPermission.denied);
      expect(NotificationPermission.fromString('maybe'), NotificationPermission.denied);
    });
  });

  group('TunnelStatistics JSON', () {
    test('round-trips through toJson/fromJson', () {
      const stats = TunnelStatistics(
        totalDownload: 54321,
        totalUpload: 12345,
        latestHandshake: 1756000000123,
      );

      final restored = TunnelStatistics.fromJson(stats.toJson());

      expect(restored.totalDownload, stats.totalDownload);
      expect(restored.totalUpload, stats.totalUpload);
      expect(restored.latestHandshake, stats.latestHandshake);
    });

    test('reads the shape the Android plugin sends', () {
      final stats = TunnelStatistics.fromJson({
        'totalDownload': 1,
        'totalUpload': 2,
        'latestHandshake': 3,
      });

      expect(stats.totalDownload, 1);
      expect(stats.totalUpload, 2);
      expect(stats.latestHandshake, 3);
    });
  });

  group('KeyPair', () {
    test('keeps the public and private keys in the documented order', () {
      final pair = KeyPair('pub', 'priv');

      expect(pair.publicKey, 'pub');
      expect(pair.privateKey, 'priv');
      expect(pair.toString(), contains('publicKey: pub'));
    });
  });
}
