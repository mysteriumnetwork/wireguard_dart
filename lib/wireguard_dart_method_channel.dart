import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/connection_status.dart';
import 'package:wireguard_dart/key_pair.dart';

import 'wireguard_dart_platform_interface.dart';

class MethodChannelWireguardDart extends WireguardDartPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('wireguard_dart');
  final statusChannel = const EventChannel('wireguard_dart/status');

  @override
  Future<KeyPair> generateKeyPair() async {
    final result = await methodChannel.invokeMapMethod<String, String>('generateKeyPair') ??
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
  Future<void> setupTunnel(
      {required String bundleId, required String tunnelName, String? win32ServiceName}) async {
    final args = {
      'bundleId': bundleId,
      'tunnelName': tunnelName,
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
    final result = await methodChannel.invokeMethod<String>('status');
    return ConnectionStatus.fromString(result ?? "");
  }

  @override
  Stream<ConnectionStatus> statusStream() {
    return statusChannel
        .receiveBroadcastStream()
        .distinct()
        .map((val) => ConnectionStatus.fromString(val));
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
    return result as bool;
  }

  @override
  Future<void> removeTunnelConfiguration(
      {required String bundleId, required String tunnelName}) async {
    await methodChannel.invokeMethod<void>('removeTunnelConfiguration', {
      'bundleId': bundleId,
      'tunnelName': tunnelName,
    });
  }
}
