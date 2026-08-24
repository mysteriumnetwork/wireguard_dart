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
    var latestHandshake = 0;
    var sawCounters = false;
    // UAPI splits a peer's handshake across `last_handshake_time_sec` and the
    // `last_handshake_time_nsec` line that follows it, so the seconds are held
    // until the nanoseconds arrive (or the next peer starts).
    int? pendingHandshakeSec;

    void commitHandshake([int nsec = 0]) {
      final seconds = pendingHandshakeSec;
      pendingHandshakeSec = null;
      // 0 means the peer has never completed a handshake.
      if (seconds == null || seconds <= 0) {
        return;
      }
      final milliseconds = seconds * 1000 + nsec ~/ 1000000;
      if (milliseconds > latestHandshake) {
        latestHandshake = milliseconds;
      }
    }

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
        commitHandshake();
        pendingHandshakeSec = value;
      } else if (key == 'last_handshake_time_nsec') {
        commitHandshake(value);
      } else if (key == 'errno' && value != 0) {
        return null;
      }
    }
    commitHandshake();

    if (!sawCounters) {
      return null;
    }

    return TunnelStatistics(
      totalDownload: totalDownload,
      totalUpload: totalUpload,
      latestHandshake: latestHandshake,
    );
  }

  /// Converts the [TunnelStatistics] object to a JSON map.
  Map<String, dynamic> toJson() => {
    'totalDownload': totalDownload,
    'totalUpload': totalUpload,
    'latestHandshake': latestHandshake,
  };
}
