class TunnelStatistics {
  final int totalDownload;
  final int totalUpload;
  final int latestHandshake;

  /// Constructor of the [Stats] class that receives [totalDownload] where total downloaded data is stored,
  /// [totalUpload] where uploaded data is stored.
  TunnelStatistics({
    required this.totalDownload,
    required this.totalUpload,
    required this.latestHandshake,
  });

  /// Factory constructor that creates a [TunnelStatistics] object from a JSON map.
  factory TunnelStatistics.fromJson(Map<String, dynamic> json) => TunnelStatistics(
      totalDownload: json['totalDownload'] as int,
      totalUpload: json['totalUpload'] as int,
      latestHandshake: json['latestHandshake'] as int);

  /// Converts the [TunnelStatistics] object to a JSON map.
  Map<String, dynamic> toJson() => {
        'totalDownload': totalDownload,
        'totalUpload': totalUpload,
        'latestHandshake': latestHandshake,
      };
}
