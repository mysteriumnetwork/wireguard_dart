import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/connection_status.dart';
import 'package:wireguard_dart/key_pair.dart';
import 'package:wireguard_dart/wireguard_dart.dart';

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
    } catch (e) {
      developer.log(
        'Generated key',
        error: e,
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
    } catch (e) {
      developer.log(
        'Is tunnel configured',
        error: e,
      );
    }
  }

  void setupTunnel() async {
    try {
      await _wireguardDartPlugin.setupTunnel(bundleId: tunBundleId, tunnelName: "WiregardDart", win32ServiceName: winSvcName);
      setState(() {
        _isTunnelSetup = true;
      });
      debugPrint("Setup tunnel success");
    } catch (e) {
      setState(() {
        _isTunnelSetup = false;
      });
      developer.log(
        'Setup tunnel',
        error: e,
      );
    }
  }

  void connect() async {
    try {
      // replace with valid config file before running
      await _wireguardDartPlugin.connect(cfg: """""");
      debugPrint("Connect success");
    } catch (e) {
      developer.log(
        'Connect',
        error: e.toString(),
      );
    }
  }

  void disconnect() async {
    try {
      await _wireguardDartPlugin.disconnect();
      debugPrint("Disconnect success");
    } catch (e) {
      developer.log(
        'Disconnect',
        error: e.toString(),
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
    } catch (e) {
      developer.log("Connection status", error: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
          constraints: const BoxConstraints.expand(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextButton(
                onPressed: generateKey,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Generate Key',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: nativeInit,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Native initialization',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: checkTunnelConfiguration,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Is Tunnel Configured',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: setupTunnel,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Setup Tunnel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: connect,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: disconnect,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Disconnect',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: status,
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all<Size>(const Size(100, 50)),
                    padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: WidgetStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Query status',
                  style: TextStyle(color: Colors.white),
                ),
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
              Text('Key pair:\n Public key:${_keyPair?.publicKey}\n Private key:${_keyPair?.privateKey}'),
            ],
          ),
        ),
      ),
    );
  }
}
