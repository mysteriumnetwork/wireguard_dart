import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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
  Future<Map<String, String>> generateKeyPair() {
    return Future(() => Map.of({
          'privateKey': 'dududu',
          'publicKey': 'dududududu',
        }));
  }
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
    expect(result, isMap);
    expect(result, containsPair('privateKey', 'dududu'));
    expect(result, containsPair('publicKey', 'dududududu'));
  });
}
