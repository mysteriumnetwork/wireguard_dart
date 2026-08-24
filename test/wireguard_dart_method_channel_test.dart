import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wireguard_dart/src/wireguard_dart_method_channel.dart';

void main() {
  final MethodChannelWireguardDart platform = MethodChannelWireguardDart();
  const MethodChannel channel = MethodChannel('wireguard_dart');

  TestWidgetsFlutterBinding.ensureInitialized();

  Object? statisticsResponse;
  var throwPlatformException = false;

  void mockChannel({bool implemented = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'tunnelStatistics') {
          if (!implemented) {
            throw MissingPluginException();
          }
          if (throwPlatformException) {
            throw PlatformException(code: 'NATIVE_ERR', message: 'not connected');
          }
          return statisticsResponse;
        }
        return null;
      },
    );
  }

  setUp(() {
    statisticsResponse = null;
    throwPlatformException = false;
    mockChannel();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  test('disconnect passes through', () async {
    await platform.disconnect();
  });

  group('getTunnelStatistics', () {
    test('parses JSON on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      statisticsResponse = jsonEncode({
        'totalDownload': 300,
        'totalUpload': 200,
        'latestHandshake': 1756000000000,
      });

      final stats = await platform.getTunnelStatistics();

      expect(stats!.totalDownload, 300);
      expect(stats.totalUpload, 200);
      expect(stats.latestHandshake, 1756000000000);
    });

    test('parses UAPI on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      statisticsResponse =
          'public_key=aa\nlast_handshake_time_sec=1756000000\n'
          'rx_bytes=300\ntx_bytes=200\nerrno=0\n\n';

      final stats = await platform.getTunnelStatistics();

      expect(stats!.totalDownload, 300);
      expect(stats.totalUpload, 200);
      expect(stats.latestHandshake, 1756000000 * 1000);
    });

    test('parses UAPI on Windows', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      statisticsResponse = 'public_key=aa\nrx_bytes=1\ntx_bytes=2\nerrno=0\n\n';

      expect((await platform.getTunnelStatistics())!.totalUpload, 2);
    });

    test('returns null when the platform returns null', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(await platform.getTunnelStatistics(), isNull);
    });

    test('returns null when the platform reports an error', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      throwPlatformException = true;

      expect(await platform.getTunnelStatistics(), isNull);
    });

    test('propagates MissingPluginException so callers can stop polling', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      mockChannel(implemented: false);

      expect(platform.getTunnelStatistics(), throwsA(isA<MissingPluginException>()));
    });
  });
}
