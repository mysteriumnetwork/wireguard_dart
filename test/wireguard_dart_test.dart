import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wireguard_dart/connection_status.dart';
import 'package:wireguard_dart/key_pair.dart';
import 'package:wireguard_dart/wireguard_dart_method_channel.dart';
import 'package:wireguard_dart/wireguard_dart_platform_interface.dart';
import 'package:wireguard_dart/wireguard_dart.dart';

class MockWireguardDartPlatform with MockPlatformInterfaceMixin implements WireguardDartPlatform {

  @override
  Future<void> nativeInit() => Future.value();

  @override
  Future<void> setupTunnel({required String bundleId, String? win32ServiceName}) => Future.value();

  @override
  Future<void> connect({required String cfg}) => Future.value();

  @override
  Future<void> disconnect() => Future.value();

  @override
  Future<KeyPair> generateKeyPair() {
    return Future(() => KeyPair("dududududu", "dududu"));
  }

  @override
  Future<ConnectionStatus> status() => Future.value(ConnectionStatus.disconnected);
}

void main() {
  final WireguardDartPlatform initialPlatform = WireguardDartPlatform.instance;

  test('$MethodChannelWireguardDart is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWireguardDart>());
  });

  test('generateKeyPair', () async {
    WireguardDart wireguardDartPlugin = WireguardDart();
    MockWireguardDartPlatform fakePlatform = MockWireguardDartPlatform();
    WireguardDartPlatform.instance = fakePlatform;

    final result = await wireguardDartPlugin.generateKeyPair();
    expect(result.publicKey, equals('dududududu'));
    expect(result.privateKey, equals('dududu'));
  });
}
