import 'models/models.dart';
import 'wireguard_dart_platform_interface.dart';

class WireguardErrorCodes {
  static const String connectionFailed = 'ERR_WIREGUARD_CONNECTION';
}

class WireguardDart {
  Future<KeyPair> generateKeyPair() {
    return WireguardDartPlatform.instance.generateKeyPair();
  }

  Future<void> nativeInit() {
    return WireguardDartPlatform.instance.nativeInit();
  }

  Future<void> setupTunnel({
    required String bundleId,
    required String tunnelName,
    String? win32ServiceName,
  }) {
    return WireguardDartPlatform.instance.setupTunnel(
      bundleId: bundleId,
      tunnelName: tunnelName,
      win32ServiceName: win32ServiceName,
    );
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

  Stream<ConnectionStatus> statusStream() {
    return WireguardDartPlatform.instance.statusStream();
  }

  Future<bool> checkTunnelConfiguration({required String bundleId, required String tunnelName}) {
    return WireguardDartPlatform.instance.checkTunnelConfiguration(
      bundleId: bundleId,
      tunnelName: tunnelName,
    );
  }

  Future<void> removeTunnelConfiguration({required String bundleId, required String tunnelName}) {
    return WireguardDartPlatform.instance.removeTunnelConfiguration(
      bundleId: bundleId,
      tunnelName: tunnelName,
    );
  }

  /// Byte counters and the latest handshake for the running tunnel.
  ///
  /// Null means there was nothing to read — no tunnel, or not connected yet.
  /// A read that *fails* is reported instead of being folded into that same
  /// null: Android and Windows throw a `PlatformException` carrying the
  /// reason, a malformed payload throws a `FormatException`, and a platform
  /// with no implementation throws `MissingPluginException` so a poller can
  /// stop for good. Apple platforms return null and log the reason natively.
  ///
  /// Polling loops therefore need a `catch` — see the README for the rest.
  Future<TunnelStatistics?> getTunnelStatistics() {
    return WireguardDartPlatform.instance.getTunnelStatistics();
  }

  Future<NotificationPermission> checkNotificationPermission() {
    return WireguardDartPlatform.instance.checkNotificationPermission();
  }

  Future<NotificationPermission> requestNotificationPermission() {
    return WireguardDartPlatform.instance.requestNotificationPermission();
  }

  Future<NotificationPermission> openAppNotificationSettings() {
    return WireguardDartPlatform.instance.openAppNotificationSettings();
  }
}
