import 'package:flutter_test/flutter_test.dart';
import 'package:wireguard_dart/src/models/tunnel_statistics.dart';

void main() {
  group('TunnelStatistics.fromUapi', () {
    test('parses a single peer', () {
      const uapi =
          'private_key=e84b5a6d2717c1003a13b431570353dbaca9146cf150c5f8575680feba52027a\n'
          'listen_port=51820\n'
          'public_key=b85996fecc9c7f1fc6d2572a76eda11d59bcd20be8e543b15ce4bd85a8e75a33\n'
          'endpoint=192.0.2.10:51820\n'
          'allowed_ip=0.0.0.0/0\n'
          'persistent_keepalive_interval=25\n'
          'last_handshake_time_sec=1756000000\n'
          'last_handshake_time_nsec=123456789\n'
          'rx_bytes=2048\n'
          'tx_bytes=1024\n'
          'errno=0\n\n';

      final stats = TunnelStatistics.fromUapi(uapi);

      expect(stats, isNotNull);
      expect(stats!.totalDownload, 2048);
      expect(stats.totalUpload, 1024);
      expect(stats.latestHandshake, 1756000000 * 1000);
    });

    test('sums byte counters across peers and takes the most recent handshake', () {
      const uapi =
          'public_key=aa\n'
          'last_handshake_time_sec=1756000000\n'
          'rx_bytes=100\n'
          'tx_bytes=10\n'
          'public_key=bb\n'
          'last_handshake_time_sec=1756000500\n'
          'rx_bytes=400\n'
          'tx_bytes=40\n'
          'errno=0\n\n';

      final stats = TunnelStatistics.fromUapi(uapi);

      expect(stats!.totalDownload, 500);
      expect(stats.totalUpload, 50);
      expect(stats.latestHandshake, 1756000500 * 1000);
    });

    test('reports a never-handshaked peer as handshake 0', () {
      const uapi = 'public_key=aa\nlast_handshake_time_sec=0\nrx_bytes=0\ntx_bytes=0\nerrno=0\n\n';

      final stats = TunnelStatistics.fromUapi(uapi);

      expect(stats!.latestHandshake, 0);
      expect(stats.totalDownload, 0);
      expect(stats.totalUpload, 0);
    });

    test('tolerates CRLF line endings', () {
      const uapi = 'public_key=aa\r\nrx_bytes=7\r\ntx_bytes=3\r\nerrno=0\r\n\r\n';

      final stats = TunnelStatistics.fromUapi(uapi);

      expect(stats!.totalDownload, 7);
      expect(stats.totalUpload, 3);
    });

    test('returns null for an empty payload', () {
      expect(TunnelStatistics.fromUapi(''), isNull);
    });

    test('returns null when the payload carries no counters', () {
      expect(TunnelStatistics.fromUapi('private_key=aa\nlisten_port=51820\nerrno=0\n\n'), isNull);
    });

    test('returns null when UAPI reports an error', () {
      const uapi = 'public_key=aa\nrx_bytes=10\ntx_bytes=5\nerrno=1\n\n';

      expect(TunnelStatistics.fromUapi(uapi), isNull);
    });
  });
}
