import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wireguard_dart/wireguard_dart_method_channel.dart';

void main() {
  MethodChannelWireguardDart platform = MethodChannelWireguardDart();
  const MethodChannel channel = MethodChannel('wireguard_dart');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'generateKeyPair':
          return null;
        case 'setupTunnel':
          return null;
        case 'status':
          return null;
        case 'connect':
          return null;
        case 'disconnect':
          return null;
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    await platform.disconnect();
  });
}
