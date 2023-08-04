import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/connection_status.dart';
import 'package:wireguard_dart/key_pair.dart';

import 'wireguard_dart_platform_interface.dart';

/// An implementation of [WireguardDartPlatform] that uses method channels.
class MethodChannelWireguardDart extends WireguardDartPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wireguard_dart');
  final statusChannel = const EventChannel('wireguard_dart.status');

  @override
  Future<KeyPair> generateKeyPair() async {
    var result = await methodChannel.invokeMapMethod<String, String>('generateKeyPair') ?? <String, String>{};
    if (!result.containsKey('publicKey') || !result.containsKey('privateKey')) {
      throw StateError('Could not generate keypair');
    };
    return KeyPair(result['publicKey']!, result['privateKey']!);
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

  @override
  Stream<ConnectionStatusChanged> onStatusChanged() {
    return statusChannel.receiveBroadcastStream().map((event) {
        var statusStr = "";
        if (event is Map) {
          statusStr = event['status'];
        }
        var status = ConnectionStatus.fromString(statusStr);
      return ConnectionStatusChanged(status);
    }).cast();
  }
}
