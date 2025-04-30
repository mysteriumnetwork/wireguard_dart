// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_statistics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunnelStatistics _$TunnelStatisticsFromJson(Map<String, dynamic> json) =>
    TunnelStatistics(
      totalDownload: json['totalDownload'] as num,
      totalUpload: json['totalUpload'] as num,
      latestHandshake: json['latestHandshake'] as num,
    );

Map<String, dynamic> _$TunnelStatisticsToJson(TunnelStatistics instance) =>
    <String, dynamic>{
      'totalDownload': instance.totalDownload,
      'totalUpload': instance.totalUpload,
      'latestHandshake': instance.latestHandshake,
    };
