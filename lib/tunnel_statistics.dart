import 'package:json_annotation/json_annotation.dart';


part 'tunnel_statistics.g.dart';
@JsonSerializable()
class TunnelStatistics {
  final num totalDownload;
  final num totalUpload;
  final num latestHandshake;

  /// Constructor of the [Stats] class that receives [totalDownload] where total downloaded data is stored,
  /// [totalUpload] where uploaded data is stored.
  TunnelStatistics({
    required this.totalDownload,
    required this.totalUpload,
    required this.latestHandshake,
  });


  factory TunnelStatistics.fromJson(Map<String, dynamic> json) => _$TunnelStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$TunnelStatisticsToJson(this);
}
