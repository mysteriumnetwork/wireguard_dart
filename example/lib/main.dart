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
      await _wireguardDartPlugin.connect(cfg: """[Interface]
PrivateKey = mC+tpn4rHNP1AINYzIqjTn7UwQM9gqsJCJTFdWYzyWM=
Address = 10.181.57.196
DNS = 8.8.8.8

[Peer]
PublicKey = rduXTxBoMW6VPQWiYvlJDyG0YBEpvjAeuhDFFippQFk=
AllowedIPs = 64.0.0.0/2, 32.0.0.0/3, 16.0.0.0/4, 8.0.0.0/5, 4.0.0.0/6, 2.0.0.0/7, 1.0.0.0/8, 0.128.0.0/9, 0.64.0.0/10, 0.32.0.0/11, 0.16.0.0/12, 0.8.0.0/13, 0.4.0.0/14, 0.2.0.0/15, 0.1.0.0/16, 0.0.128.0/17, 0.0.64.0/18, 0.0.32.0/19, 0.0.16.0/20, 0.0.8.0/21, 0.0.4.0/22, 0.0.2.0/23, 0.0.1.0/24, 0.0.0.128/25, 0.0.0.64/26, 0.0.0.32/27, 0.0.0.16/28, 0.0.0.8/29, 0.0.0.4/30, 0.0.0.2/31, 0.0.0.1/32, 192.0.0.0/2, 128.0.0.0/3, 176.0.0.0/4, 168.0.0.0/5, 160.0.0.0/6, 164.0.0.0/7, 166.0.0.0/8, 167.0.0.0/9, 167.128.0.0/10, 167.192.0.0/11, 167.240.0.0/12, 167.224.0.0/13, 167.236.0.0/14, 167.232.0.0/15, 167.234.0.0/16, 167.235.0.0/17, 167.235.192.0/18, 167.235.160.0/19, 167.235.128.0/20, 167.235.152.0/21, 167.235.148.0/22, 167.235.146.0/23, 167.235.145.0/24, 167.235.144.0/25, 167.235.144.192/26, 167.235.144.128/27, 167.235.144.176/28, 167.235.144.160/29, 167.235.144.172/30, 167.235.144.170/31, 167.235.144.169/32
Endpoint = 167.235.144.168:56666
PersistentKeepalive = 15
""");
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
