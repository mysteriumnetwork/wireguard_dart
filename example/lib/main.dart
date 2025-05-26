import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/connection_status.dart';
import 'package:wireguard_dart/key_pair.dart';
import 'package:wireguard_dart/tunnel_statistics.dart';
import 'package:wireguard_dart/wireguard_dart.dart';
import 'package:wireguard_dart_example/snackbar.dart';

const tunBundleId = "network.mysterium.wireguardDartExample.tun";
const winSvcName = "Wireguard_Dart_Example";

void main() {
  runApp(const MyApp());
}

void nativeInitBackground(List<Object> args) async {
  final rootIsolateToken = args[0] as RootIsolateToken;
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  try {
    await WireguardDart().nativeInit();
    debugPrint('Native init done');
  } catch (e) {
    debugPrint('Native init error');
    developer.log(
      'Native init',
      error: e.toString(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _wireguardDartPlugin = WireguardDart();
  ConnectionStatus _status = ConnectionStatus.unknown;
  late Stream<ConnectionStatus> _statusStream;
  bool? _checkTunnelConfiguration;
  bool? _isTunnelSetup;
  KeyPair? _keyPair;
  TunnelStatistics? _lastTunnelStatistics;
  Stream<TunnelStatistics>? _tunnelStatisticsStream;
  num uploadSpeedKBs = 0;
  num downloadSpeedKBs = 0;

  @override
  void initState() {
    super.initState();
    _statusStream = _wireguardDartPlugin.statusStream();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = '';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      debugPrint(_platformVersion);
    });
  }

  void generateKey() async {
    try {
      var keyPair = await _wireguardDartPlugin.generateKeyPair();
      setState(() {
        _keyPair = keyPair;
      });
      debugPrint('Generated key pair: $_keyPair');
      showSnackbar(
        "Generated key pair: ${keyPair.publicKey}",
        type: MessageType.success,
      );
    } catch (e) {
      developer.log(
        'Generated key',
        error: e,
      );
      showSnackbar(
        "Failed to generate key pair: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  void nativeInit() async {
    RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    Isolate.spawn(nativeInitBackground, [rootIsolateToken]);
  }

  Future<void> checkTunnelConfiguration() async {
    try {
      final status = await _wireguardDartPlugin.checkTunnelConfiguration(
        bundleId: tunBundleId,
        tunnelName: "WiregardDart",
      );
      setState(() {
        _checkTunnelConfiguration = status;
      });
      debugPrint("Tunnel configured status: $_checkTunnelConfiguration");
      showSnackbar(
        "Tunnel configured status: $_checkTunnelConfiguration",
        type: MessageType.success,
      );
    } catch (e) {
      developer.log(
        'Is tunnel configured',
        error: e,
      );
      showSnackbar(
        "Failed to check tunnel configuration: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  void setupTunnel() async {
    try {
      await _wireguardDartPlugin.setupTunnel(
          bundleId: tunBundleId, tunnelName: "WiregardDart", win32ServiceName: winSvcName);
      setState(() {
        _isTunnelSetup = true;
      });
      debugPrint("Setup tunnel success");
      showSnackbar(
        "Setup tunnel success",
        type: MessageType.success,
      );
    } catch (e) {
      setState(() {
        _isTunnelSetup = false;
      });
      developer.log(
        'Setup tunnel',
        error: e,
      );
      showSnackbar(
        "Failed to setup tunnel: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  void connect() async {
    try {
      // replace with valid config file before running
      await _wireguardDartPlugin.connect(cfg: """""");
      debugPrint("Connect success");
      showSnackbar(
        "Connect success",
        type: MessageType.success,
      );
      setState(() {
        _tunnelStatisticsStream = tunnelStatisticsStream(const Duration(seconds: 1));
      });
    } catch (e) {
      developer.log(
        'Connect',
        error: e.toString(),
      );
      showSnackbar(
        "Failed to connect: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  void disconnect() async {
    try {
      await _wireguardDartPlugin.disconnect();
      debugPrint("Disconnect success");
      showSnackbar(
        "Disconnect success",
        type: MessageType.success,
      );
    } catch (e) {
      developer.log(
        'Disconnect',
        error: e.toString(),
      );
      showSnackbar(
        "Failed to disconnect: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  void removeTunnelConfiguration() async {
    try {
      await _wireguardDartPlugin.removeTunnelConfiguration(
          bundleId: tunBundleId, tunnelName: "WiregardDart");
      debugPrint("Remove tunnel configuration success");
      showSnackbar(
        "Remove tunnel configuration success",
        type: MessageType.success,
      );
    } catch (e) {
      developer.log(
        'Remove tunnel configuration',
        error: e.toString(),
      );
      showSnackbar(
        "Failed to remove tunnel configuration: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  void status() async {
    try {
      var status = await _wireguardDartPlugin.status();
      debugPrint("Connection status: $status");
      setState(() {
        _status = status;
      });
      showSnackbar(
        "Connection status: ${status.name}",
        type: MessageType.success,
      );
    } catch (e) {
      developer.log("Connection status", error: e.toString());
      showSnackbar(
        "Failed to get connection status: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  Future<void> getTunnelStatistics() async {
    try {
      var stats = await _wireguardDartPlugin.getTunnelStatistics();
      debugPrint("Tunnel statistics: $stats");
      showSnackbar(
        "Tunnel statistics: ${stats?.toJson()}",
        type: MessageType.success,
      );
    } catch (e) {
      developer.log("Tunnel statistics", error: e.toString());
      showSnackbar(
        "Failed to get tunnel statistics: ${e.toString()}",
        type: MessageType.error,
      );
    }
  }

  Stream<TunnelStatistics> tunnelStatisticsStream(Duration interval) async* {
    while (true) {
      await Future.delayed(interval);
      final prevStats = _lastTunnelStatistics;
      var stats = await _wireguardDartPlugin.getTunnelStatistics();
      if (prevStats != null && stats != null) {
        uploadSpeedKBs = ((stats.totalUpload - prevStats.totalUpload) / interval.inSeconds) / 1024;
        downloadSpeedKBs =
            ((stats.totalDownload - prevStats.totalDownload) / interval.inSeconds) / 1024;
      }
      yield _lastTunnelStatistics = stats!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
          constraints: const BoxConstraints.expand(),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: generateKey,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Generate Key',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    if (Platform.isWindows)
                      TextButton(
                        onPressed: nativeInit,
                        style: ButtonStyle(
                            minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                            padding:
                                WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                            backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                            overlayColor: WidgetStateProperty.all<Color>(
                                Colors.white.withValues(alpha: 0.1))),
                        child: const Text(
                          'Native initialization',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    TextButton(
                      onPressed: checkTunnelConfiguration,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Is Tunnel Configured',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: setupTunnel,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Setup Tunnel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: connect,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Connect',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: disconnect,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Disconnect',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    if (Platform.isIOS || Platform.isMacOS)
                      TextButton(
                        onPressed: removeTunnelConfiguration,
                        style: ButtonStyle(
                            minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                            padding:
                                WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                            backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                            overlayColor: WidgetStateProperty.all<Color>(
                                Colors.white.withValues(alpha: 0.1))),
                        child: const Text(
                          'Remove tunnel configuration',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    TextButton(
                      onPressed: status,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Query status',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: getTunnelStatistics,
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                          backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                          overlayColor:
                              WidgetStateProperty.all<Color>(Colors.white.withValues(alpha: 0.1))),
                      child: const Text(
                        'Get tunnel statistics',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text("Query tunnel status: ${_status.name}"),
                StreamBuilder<ConnectionStatus>(
                    initialData: ConnectionStatus.unknown,
                    stream: _statusStream,
                    builder: (BuildContext context, AsyncSnapshot<ConnectionStatus> snapshot) {
                      // Check if the snapshot has data and is a map containing the 'status' key
                      if (snapshot.hasData) {
                        return Text("Tunnel stream status: ${snapshot.data!.name}");
                      }
                      return const CircularProgressIndicator();
                    }),
                Text('Tunnel configured: $_checkTunnelConfiguration'),
                Text('Tunnel setup: $_isTunnelSetup'),
                Text(
                    'Key pair:\n Public key:${_keyPair?.publicKey}\n Private key:${_keyPair?.privateKey}'),
                StreamBuilder<TunnelStatistics>(
                    initialData: const TunnelStatistics(
                        latestHandshake: 0, totalDownload: 0, totalUpload: 0),
                    stream: _tunnelStatisticsStream,
                    builder: (BuildContext context, AsyncSnapshot<TunnelStatistics> snapshot) {
                      // Check if the snapshot has data and is a map containing the 'status' key
                      if (snapshot.hasData) {
                        final handshakeTime = DateTime.fromMillisecondsSinceEpoch(
                                snapshot.data!.latestHandshake.toInt())
                            .toLocal();
                        return Text(
                          """Tunnel statistics:
                        Latest handshake: $handshakeTime
                        Total download: ${snapshot.data?.totalDownload}
                        Total Upload: ${snapshot.data?.totalUpload}
                        Upload speed: ${uploadSpeedKBs.toStringAsFixed(2)} KB/s
                        Download speed: ${downloadSpeedKBs.toStringAsFixed(2)} KB/s

                            """,
                        );
                      }
                      return const CircularProgressIndicator();
                    }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
