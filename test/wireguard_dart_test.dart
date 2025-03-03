import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wireguard_dart/connection_status.dart';
import 'package:wireguard_dart/key_pair.dart';
import 'package:wireguard_dart/wireguard_dart.dart';
import 'package:wireguard_dart/wireguard_dart_platform_interface.dart';

import 'wireguard_dart_test.mocks.dart' as base_mock;

// Add the mixin to make the platform interface accept the mock.
class _MockImagePickerPlatform extends base_mock.MockWireguardDartPlatform with MockPlatformInterfaceMixin {}

@GenerateMocks(<Type>[], customMocks: <MockSpec<dynamic>>[MockSpec<WireguardDartPlatform>()])
void main() {
  late WireguardDart wireguardDart;
  late _MockImagePickerPlatform mockWireGuardDartPlatform;

  setUp(() {
    mockWireGuardDartPlatform = _MockImagePickerPlatform();
    WireguardDartPlatform.instance = mockWireGuardDartPlatform;
    wireguardDart = WireguardDart();
  });

  group('WireguardDart', () {
    test('should generate key pair successfully', () async {
      final keyPair = KeyPair('publicKey', 'privateKey');
      when(mockWireGuardDartPlatform.generateKeyPair()).thenAnswer((_) async => keyPair);

      final result = await wireguardDart.generateKeyPair();

      expect(result, keyPair);
      verify(mockWireGuardDartPlatform.generateKeyPair()).called(1);
    });

    test('should handle error when generating key pair', () async {
      when(mockWireGuardDartPlatform.generateKeyPair()).thenThrow(Exception('Failed to generate key pair'));

      expect(() => wireguardDart.generateKeyPair(), throwsException);
      verify(mockWireGuardDartPlatform.generateKeyPair()).called(1);
    });

    test('should initialize native successfully', () async {
      when(mockWireGuardDartPlatform.nativeInit()).thenAnswer((_) async => Future.value());

      await wireguardDart.nativeInit();

      verify(mockWireGuardDartPlatform.nativeInit()).called(1);
    });

    test('should handle error when initializing native', () async {
      when(mockWireGuardDartPlatform.nativeInit()).thenThrow(Exception('Failed to initialize native'));

      expect(() => wireguardDart.nativeInit(), throwsException);
      verify(mockWireGuardDartPlatform.nativeInit()).called(1);
    });

    test('should setup tunnel successfully', () async {
      when(mockWireGuardDartPlatform.setupTunnel(
              bundleId: anyNamed('bundleId'), tunnelName: anyNamed('tunnelName'), win32ServiceName: anyNamed('win32ServiceName')))
          .thenAnswer((_) async => Future.value());

      await wireguardDart.setupTunnel(bundleId: 'bundleId', tunnelName: 'tunnelName', win32ServiceName: 'win32ServiceName');

      verify(mockWireGuardDartPlatform.setupTunnel(bundleId: 'bundleId', tunnelName: 'tunnelName', win32ServiceName: 'win32ServiceName')).called(1);
    });

    test('should handle error when setting up tunnel', () async {
      when(mockWireGuardDartPlatform.setupTunnel(
              bundleId: anyNamed('bundleId'), tunnelName: anyNamed('tunnelName'), win32ServiceName: anyNamed('win32ServiceName')))
          .thenThrow(Exception('Failed to setup tunnel'));

      expect(() => wireguardDart.setupTunnel(bundleId: 'bundleId', tunnelName: 'tunnelName', win32ServiceName: 'win32ServiceName'), throwsException);
      verify(mockWireGuardDartPlatform.setupTunnel(bundleId: 'bundleId', tunnelName: 'tunnelName', win32ServiceName: 'win32ServiceName')).called(1);
    });

    test('should connect successfully', () async {
      when(mockWireGuardDartPlatform.connect(cfg: anyNamed('cfg'))).thenAnswer((_) async => Future.value());

      await wireguardDart.connect(cfg: 'config');

      verify(mockWireGuardDartPlatform.connect(cfg: 'config')).called(1);
    });

    test('should handle error when connecting', () async {
      when(mockWireGuardDartPlatform.connect(cfg: anyNamed('cfg'))).thenThrow(Exception('Failed to connect'));

      expect(() => wireguardDart.connect(cfg: 'config'), throwsException);
      verify(mockWireGuardDartPlatform.connect(cfg: 'config')).called(1);
    });

    test('should disconnect successfully', () async {
      when(mockWireGuardDartPlatform.disconnect()).thenAnswer((_) async => Future.value());

      await wireguardDart.disconnect();

      verify(mockWireGuardDartPlatform.disconnect()).called(1);
    });

    test('should handle error when disconnecting', () async {
      when(mockWireGuardDartPlatform.disconnect()).thenThrow(Exception('Failed to disconnect'));

      expect(() => wireguardDart.disconnect(), throwsException);
      verify(mockWireGuardDartPlatform.disconnect()).called(1);
    });

    test('should get status successfully', () async {
      const status = ConnectionStatus.connected;
      when(mockWireGuardDartPlatform.status()).thenAnswer((_) async => status);

      final result = await wireguardDart.status();

      expect(result, status);
      verify(mockWireGuardDartPlatform.status()).called(1);
    });

    test('should handle error when getting status', () async {
      when(mockWireGuardDartPlatform.status()).thenThrow(Exception('Failed to get status'));

      expect(() => wireguardDart.status(), throwsException);
      verify(mockWireGuardDartPlatform.status()).called(1);
    });

    test('should get status stream successfully', () async {
      final statusStream = Stream<ConnectionStatus>.fromIterable([ConnectionStatus.connected]);
      when(mockWireGuardDartPlatform.statusStream()).thenAnswer((_) => statusStream);

      final result = wireguardDart.statusStream();

      expect(await result.first, ConnectionStatus.connected);
      verify(mockWireGuardDartPlatform.statusStream()).called(1);
    });

    test('should handle error when getting status stream', () async {
      when(mockWireGuardDartPlatform.statusStream()).thenThrow(Exception('Failed to get status stream'));

      expect(() => wireguardDart.statusStream(), throwsException);
      verify(mockWireGuardDartPlatform.statusStream()).called(1);
    });

    test('should check tunnel configuration successfully', () async {
      when(mockWireGuardDartPlatform.checkTunnelConfiguration(bundleId: anyNamed('bundleId'), tunnelName: anyNamed('tunnelName')))
          .thenAnswer((_) async => true);

      final result = await wireguardDart.checkTunnelConfiguration(bundleId: 'bundleId', tunnelName: 'tunnelName');

      expect(result, true);
      verify(mockWireGuardDartPlatform.checkTunnelConfiguration(bundleId: 'bundleId', tunnelName: 'tunnelName')).called(1);
    });

    test('should handle error when checking tunnel configuration', () async {
      when(mockWireGuardDartPlatform.checkTunnelConfiguration(bundleId: anyNamed('bundleId'), tunnelName: anyNamed('tunnelName')))
          .thenThrow(Exception('Failed to check tunnel configuration'));

      expect(() => wireguardDart.checkTunnelConfiguration(bundleId: 'bundleId', tunnelName: 'tunnelName'), throwsException);
      verify(mockWireGuardDartPlatform.checkTunnelConfiguration(bundleId: 'bundleId', tunnelName: 'tunnelName')).called(1);
    });
  });

  test('should generate key pair and check if the key from the store is expected', () async {
    final expectedKeyPair = KeyPair('expectedPublicKey', 'expectedPrivateKey');
    when(mockWireGuardDartPlatform.generateKeyPair()).thenAnswer((_) async => expectedKeyPair);

    final result = await wireguardDart.generateKeyPair();

    expect(result.publicKey, 'expectedPublicKey');
    expect(result.privateKey, 'expectedPrivateKey');
    verify(mockWireGuardDartPlatform.generateKeyPair()).called(1);
  });

  test('should throw not implemented exception for generateKeyPair', () async {
    when(mockWireGuardDartPlatform.generateKeyPair()).thenThrow(UnimplementedError('generateKeyPair not implemented'));

    expect(() => wireguardDart.generateKeyPair(), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.generateKeyPair()).called(1);
  });

  test('should throw not implemented exception for nativeInit', () async {
    when(mockWireGuardDartPlatform.nativeInit()).thenThrow(UnimplementedError('nativeInit not implemented'));

    expect(() => wireguardDart.nativeInit(), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.nativeInit()).called(1);
  });

  test('should throw not implemented exception for setupTunnel', () async {
    when(mockWireGuardDartPlatform.setupTunnel(
            bundleId: anyNamed('bundleId'), tunnelName: anyNamed('tunnelName'), win32ServiceName: anyNamed('win32ServiceName')))
        .thenThrow(UnimplementedError('setupTunnel not implemented'));

    expect(() => wireguardDart.setupTunnel(bundleId: 'bundleId', tunnelName: 'tunnelName', win32ServiceName: 'win32ServiceName'),
        throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.setupTunnel(bundleId: 'bundleId', tunnelName: 'tunnelName', win32ServiceName: 'win32ServiceName')).called(1);
  });

  test('should throw not implemented exception for connect', () async {
    when(mockWireGuardDartPlatform.connect(cfg: anyNamed('cfg'))).thenThrow(UnimplementedError('connect not implemented'));

    expect(() => wireguardDart.connect(cfg: 'config'), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.connect(cfg: 'config')).called(1);
  });

  test('should throw not implemented exception for disconnect', () async {
    when(mockWireGuardDartPlatform.disconnect()).thenThrow(UnimplementedError('disconnect not implemented'));

    expect(() => wireguardDart.disconnect(), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.disconnect()).called(1);
  });

  test('should throw not implemented exception for status', () async {
    when(mockWireGuardDartPlatform.status()).thenThrow(UnimplementedError('status not implemented'));

    expect(() => wireguardDart.status(), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.status()).called(1);
  });

  test('should throw not implemented exception for statusStream', () async {
    when(mockWireGuardDartPlatform.statusStream()).thenThrow(UnimplementedError('statusStream not implemented'));

    expect(() => wireguardDart.statusStream(), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.statusStream()).called(1);
  });

  test('should throw not implemented exception for checkTunnelConfiguration', () async {
    when(mockWireGuardDartPlatform.checkTunnelConfiguration(bundleId: anyNamed('bundleId'), tunnelName: anyNamed('tunnelName')))
        .thenThrow(UnimplementedError('checkTunnelConfiguration not implemented'));

    expect(() => wireguardDart.checkTunnelConfiguration(bundleId: 'bundleId', tunnelName: 'tunnelName'), throwsA(isA<UnimplementedError>()));
    verify(mockWireGuardDartPlatform.checkTunnelConfiguration(bundleId: 'bundleId', tunnelName: 'tunnelName')).called(1);
  });

  test('should return error when wrong config is sent', () async {
    when(mockWireGuardDartPlatform.connect(cfg: anyNamed('cfg'))).thenThrow(Exception('Invalid config'));

    expect(() => wireguardDart.connect(cfg: 'wrongConfig'), throwsException);
    verify(mockWireGuardDartPlatform.connect(cfg: 'wrongConfig')).called(1);
  });
}
