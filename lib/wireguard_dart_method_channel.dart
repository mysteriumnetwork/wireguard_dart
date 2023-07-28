import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/connection_status.dart';

import 'wireguard_dart_platform_interface.dart';

/// An implementation of [WireguardDartPlatform] that uses method channels.
class MethodChannelWireguardDart extends WireguardDartPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wireguard_dart');

  @override
  Future<Map<String, String>> generateKeyPair() async {
    var result = await methodChannel.invokeMapMethod<String, String>('generateKeyPair') ?? <String, String>{};
    return result;
  }

  @override
  Future<void> nativeInit() async {
    await methodChannel.invokeMethod<void>('nativeInit');
  }

  @override
  Future<void> setupTunnel({required String bundleId, String? win32ServiceName}) async {
    var args = {
      'bundleId': bundleId,
      if (win32ServiceName != null) 'win32ServiceName': win32ServiceName,
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
    var result = await methodChannel.invokeMapMethod<String, String>('status') ?? <String, String>{};
    return ConnectionStatus.fromString(result['status'] ?? '');
  }
}
