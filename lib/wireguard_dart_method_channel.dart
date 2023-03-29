import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wireguard_dart_platform_interface.dart';

/// An implementation of [WireguardDartPlatform] that uses method channels.
class MethodChannelWireguardDart extends WireguardDartPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wireguard_dart');

  @override
  Future<Map<String, String>> generateKeyPair() async {
    return Map<String, String>.from(await methodChannel.invokeMethod('generateKeyPair'));
  }

  @override
  Future<void> setupTunnel({required String bundleId}) async {
    await methodChannel.invokeMethod<void>('setupTunnel', {'bundleId': bundleId});
  }

  @override
  Future<void> connect({required String cfg}) async {
    await methodChannel.invokeMethod<void>('connect', {'cfg': cfg});
  }

  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod<void>('disconnect');
  }
}
