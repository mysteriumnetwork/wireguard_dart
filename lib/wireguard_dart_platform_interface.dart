import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wireguard_dart/tunnel_statistics.dart';

import 'connection_status.dart';
import 'key_pair.dart';
import 'wireguard_dart_method_channel.dart';

abstract class WireguardDartPlatform extends PlatformInterface {
  /// Constructs a WireguardDartPlatform.
  WireguardDartPlatform() : super(token: _token);

  static final Object _token = Object();

  static WireguardDartPlatform _instance = MethodChannelWireguardDart();

  /// The default instance of [WireguardDartPlatform] to use.
  ///
  /// Defaults to [MethodChannelWireguardDart].
  static WireguardDartPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WireguardDartPlatform] when
  /// they register themselves.
  static set instance(WireguardDartPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<KeyPair> generateKeyPair() {
    throw UnimplementedError('generateKeyPair() has not been implemented');
  }

  Future<void> nativeInit() {
    throw UnimplementedError('nativeInit() has not been implemented');
  }

  Future<void> setupTunnel(
      {required String bundleId, required String tunnelName, String? win32ServiceName}) {
    throw UnimplementedError('setupTunnel() has not been implemented');
  }

  Future<void> connect({required String cfg}) {
    throw UnimplementedError('connect() has not been implemented');
  }

  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented');
  }

  Future<ConnectionStatus> status() {
    throw UnimplementedError('status() has not been implemented');
  }

  Stream<ConnectionStatus> statusStream() {
    throw UnimplementedError('statusStream() has not been implemented');
  }

  Future<bool> checkTunnelConfiguration({
    required String bundleId,
    required String tunnelName,
  }) {
    throw UnimplementedError('checkTunnelConfiguration() has not been implemented');
  }

  Future<void> removeTunnelConfiguration({required String bundleId, required String tunnelName}) {
    throw UnimplementedError('removeTunnelConfiguration() has not been implemented');
  }

  Future<TunnelStatistics?> getTunnelStatistics() {
    throw UnimplementedError('getTunnelStatistics() has not been implemented');
  }
}
