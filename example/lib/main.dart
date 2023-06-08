import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_dart/wireguard_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _wireguardDartPlugin = WireguardDart();

  @override
  void initState() {
    super.initState();
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

  void generateKey() {
    _wireguardDartPlugin.generateKeyPair().then((value) => {
          developer.log(
            'generated key',
            error: value.toString(),
          )
        });
  }

  void setupTunnel() async {
    try {
      await _wireguardDartPlugin.setupTunnel(bundleId: "mysterium");
      debugPrint("setupTunnel success");
    } catch (e) {
      developer.log(
        'setupTunnel',
        error: e.toString(),
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
      debugPrint("disconnect success");
    } catch (e) {
      developer.log(
        'disconnect',
        error: e.toString(),
      );
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
                    minimumSize: MaterialStateProperty.all<Size>(const Size(100, 50)),
                    padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: MaterialStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Generate Key',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: setupTunnel,
                style: ButtonStyle(
                    minimumSize: MaterialStateProperty.all<Size>(const Size(100, 50)),
                    padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: MaterialStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Setup Tunnel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: connect,
                style: ButtonStyle(
                    minimumSize: MaterialStateProperty.all<Size>(const Size(100, 50)),
                    padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: MaterialStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: disconnect,
                style: ButtonStyle(
                    minimumSize: MaterialStateProperty.all<Size>(const Size(100, 50)),
                    padding: MaterialStateProperty.all(const EdgeInsets.fromLTRB(20, 15, 20, 15)),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueAccent),
                    overlayColor: MaterialStateProperty.all<Color>(Colors.white.withOpacity(0.1))),
                child: const Text(
                  'Disconnect',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
