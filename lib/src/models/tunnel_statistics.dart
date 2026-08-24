class TunnelStatistics {
  final int totalDownload;
  final int totalUpload;
  final int latestHandshake;

  /// Constructor of the [TunnelStatistics] class that receives
  /// [totalDownload], [totalUpload], and [latestHandshake] as parameters.
  /// [totalDownload] and [totalUpload] are the total bytes downloaded
  /// and uploaded, respectively. [latestHandshake] is the timestamp of
  /// the latest handshake.
  const TunnelStatistics({
    required this.totalDownload,
    required this.totalUpload,
    required this.latestHandshake,
  });

  /// Factory constructor that creates a [TunnelStatistics] object from a JSON map.
  factory TunnelStatistics.fromJson(Map<String, dynamic> json) => TunnelStatistics(
    totalDownload: json['totalDownload'] as int,
    totalUpload: json['totalUpload'] as int,
    latestHandshake: json['latestHandshake'] as int,
  );

  /// Parses WireGuard's UAPI text format — the output of `wgGetConfig` on Apple
  /// platforms and of `get=1` on the Windows tunnel service pipe.
  ///
  /// Byte counters are summed across peers and the handshake is the most recent
  /// one, converted from UAPI seconds to epoch milliseconds so the value matches
  /// what Android reports. Returns null when the payload carries no peer
  /// counters or when UAPI reports a non-zero `errno`.
  static TunnelStatistics? fromUapi(String uapi) {
    var totalDownload = 0;
    var totalUpload = 0;
    var latestHandshakeSec = 0;
    var sawCounters = false;

    for (final rawLine in uapi.split('\n')) {
      final line = rawLine.trim();
      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = line.substring(0, separator);
      final value = int.tryParse(line.substring(separator + 1));
      if (value == null) {
        continue;
      }

      if (key == 'rx_bytes') {
        totalDownload += value;
        sawCounters = true;
      } else if (key == 'tx_bytes') {
        totalUpload += value;
        sawCounters = true;
      } else if (key == 'last_handshake_time_sec') {
        if (value > latestHandshakeSec) {
          latestHandshakeSec = value;
        }
      } else if (key == 'errno' && value != 0) {
        return null;
      }
    }

    if (!sawCounters) {
      return null;
    }

    return TunnelStatistics(
      totalDownload: totalDownload,
      totalUpload: totalUpload,
      latestHandshake: latestHandshakeSec * 1000,
    );
  }

  /// Converts the [TunnelStatistics] object to a JSON map.
  Map<String, dynamic> toJson() => {
    'totalDownload': totalDownload,
    'totalUpload': totalUpload,
    'latestHandshake': latestHandshake,
  };
}
