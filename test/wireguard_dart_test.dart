import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wireguard_dart/wireguard_dart_method_channel.dart';
import 'package:wireguard_dart/wireguard_dart_platform_interface.dart';

class MockWireguardDartPlatform with MockPlatformInterfaceMixin implements WireguardDartPlatform {
  @override
  Future<void> setupTunnel({required String bundleId}) => Future.value();

  @override
  Future<void> connect({required String cfg}) => Future.value();

  @override
  Future<void> disconnect() => Future.value();
}

void main() {
  final WireguardDartPlatform initialPlatform = WireguardDartPlatform.instance;

  test('$MethodChannelWireguardDart is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWireguardDart>());
  });

  // test('setupTunnel', () async {
  //   WireguardDart wireguardDartPlugin = WireguardDart();
  //   MockWireguardDartPlatform fakePlatform = MockWireguardDartPlatform();
  //   WireguardDartPlatform.instance = fakePlatform;

  //   expect(await wireguardDartPlugin.setupTunnel());
  // });
}
