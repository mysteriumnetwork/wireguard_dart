import 'wireguard_dart_platform_interface.dart';

class WireguardDart {
  Future<Map<String, String>> generateKeyPair() {
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
}
