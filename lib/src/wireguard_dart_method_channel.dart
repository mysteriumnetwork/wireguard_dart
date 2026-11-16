import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/src/models/models.dart';

import 'wireguard_dart_platform_interface.dart';

class MethodChannelWireguardDart extends WireguardDartPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('wireguard_dart');
  final statusChannel = const EventChannel('wireguard_dart/status');

  @override
  Future<KeyPair> generateKeyPair() async {
    final result =
        await methodChannel.invokeMapMethod<String, String>('generateKeyPair') ??
        <String, String>{};
    if (!result.containsKey('publicKey') || !result.containsKey('privateKey')) {
      throw StateError('Could not generate keypair');
    }
    return KeyPair(result['publicKey']!, result['privateKey']!);
  }

  @override
  Future<void> nativeInit() async {
    await methodChannel.invokeMethod<void>('nativeInit');
  }

  @override
  Future<void> setupTunnel({
    required String bundleId,
    required String tunnelName,
    String? win32ServiceName,
  }) async {
    final args = {
      'bundleId': bundleId,
      'tunnelName': tunnelName,
      'win32ServiceName': ?win32ServiceName,
    };
    await methodChannel.invokeMethod<void>('setupTunnel', args);
  }

  @override
  Future<void> connect({required String cfg}) async {
    await methodChannel.invokeMethod<void>('connect', {'cfg': cfg});
  }

  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod<void>('disconnect');
  }

  @override
  Future<ConnectionStatus> status() async {
    final result = await methodChannel.invokeMethod<String>('status');
    return ConnectionStatus.fromString(result ?? "");
  }

  @override
  Stream<ConnectionStatus> statusStream() {
    return statusChannel.receiveBroadcastStream().distinct().map(
      (val) => ConnectionStatus.fromString(val),
    );
  }

  @override
  Future<bool> checkTunnelConfiguration({
    required String bundleId,
    required String tunnelName,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('checkTunnelConfiguration', {
      'bundleId': bundleId,
      'tunnelName': tunnelName,
    });
    // A platform that answered with nothing has not told us the tunnel is
    // missing — a bare cast here would throw a TypeError that callers catching
    // PlatformException never see.
    if (result == null) {
      throw PlatformException(
        code: 'NATIVE_ERR',
        message: 'checkTunnelConfiguration returned no value',
      );
    }
    return result;
  }

  @override
  Future<void> removeTunnelConfiguration({
    required String bundleId,
    required String tunnelName,
  }) async {
    await methodChannel.invokeMethod<void>('removeTunnelConfiguration', {
      'bundleId': bundleId,
      'tunnelName': tunnelName,
    });
  }

  /// Null when there is no tunnel to read, and **throws** when the platform
  /// reports a failure.
  ///
  /// The error used to be swallowed into that same null. It meant a total
  /// failure of the Android counters was indistinguishable from an idle
  /// tunnel, and it stayed invisible for as long as it did because of it.
  /// Callers already handle [MissingPluginException] from here, so a
  /// [PlatformException] is nothing new for them to catch.
  @override
  Future<TunnelStatistics?> getTunnelStatistics() async {
    final result = await methodChannel.invokeMethod<Object?>('tunnelStatistics');

    if (result is! String || result.isEmpty) {
      return null;
    }

    // Android returns JSON; darwin and Windows return raw UAPI text.
    if (defaultTargetPlatform == TargetPlatform.android) {
      // A null snapshot serialises to the literal string "null", which decodes
      // to null rather than to a map.
      final decoded = jsonDecode(result);
      return decoded is Map<String, dynamic> ? TunnelStatistics.fromJson(decoded) : null;
    }
    return TunnelStatistics.fromUapi(result);
  }

  @override
  Future<NotificationPermission> checkNotificationPermission() async {
    final String result = await methodChannel.invokeMethod('checkNotificationPermission');
    return NotificationPermission.fromString(result);
  }

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    try {
      final String result = await methodChannel.invokeMethod('requestNotificationPermission');
      return NotificationPermission.fromString(result);
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<NotificationPermission> openAppNotificationSettings() async {
    try {
      final String result = await methodChannel.invokeMethod('openAppNotificationSettings');
      return NotificationPermission.fromString(result);
    } catch (e) {
      throw Exception(e);
    }
  }
}
