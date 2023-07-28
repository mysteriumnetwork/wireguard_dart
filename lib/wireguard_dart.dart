import 'package:wireguard_dart/key_pair.dart';

import 'connection_status.dart';
import 'wireguard_dart_platform_interface.dart';

class WireguardDart {
  Future<KeyPair> generateKeyPair() {
    return WireguardDartPlatform.instance.generateKeyPair();
  }

  Future<void> nativeInit() {
    return WireguardDartPlatform.instance.nativeInit();
  }

  Future<void> setupTunnel({required String bundleId, String? win32ServiceName}) {
    return WireguardDartPlatform.instance.setupTunnel(bundleId: bundleId, win32ServiceName: win32ServiceName);
  }

  Future<void> connect({required String cfg}) {
    return WireguardDartPlatform.instance.connect(cfg: cfg);
  }

  Future<void> disconnect() {
    return WireguardDartPlatform.instance.disconnect();
  }

  Future<ConnectionStatus> status() {
    return WireguardDartPlatform.instance.status();
  }
}
