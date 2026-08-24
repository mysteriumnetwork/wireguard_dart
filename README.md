# wireguard_dart

A Flutter plugin to set up and control a VPN connection over a [WireGuard](https://www.wireguard.com/) tunnel.

It embeds [WireGuard's own implementation for each OS](https://www.wireguard.com/embedding/) —
WireGuardKit on Apple platforms, `com.wireguard.android:tunnel` on Android, and the official
`tunnel.dll` service on Windows — so a host app needs no additional VPN dependency.

<p>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-3.44.7-02569B?logo=flutter&logoColor=white" alt="Flutter 3.44.7">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-8A2BE2" alt="Platforms">
</p>

## Platform support

| | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| **Minimum version** | API 24 | 15.0 | 12.0 | 10 | — |
| **Engine** | `com.wireguard.android:tunnel` | WireGuardKit | WireGuardKit | `tunnel.dll` + `wireguard.dll` | — |
| Connect / disconnect | ✅ | ✅ | ✅ | ✅ | ❌ |
| Status stream | ✅ | ✅ | ✅ | ✅ | ❌ |
| Key generation | ✅ | ✅ | ✅ | ✅ | ❌ |
| Tunnel configuration check / removal | ✅ | ✅ | ✅ | ✅ | ❌ |
| Tunnel statistics | ✅ | ✅ | ✅ | ✅ | ❌ |
| Notification permission helpers | ✅ | n/a | n/a | n/a | ❌ |

Linux ships a stub plugin that answers only `getPlatformVersion`; every other method throws
`MissingPluginException`.

## Installation

The plugin is not published to pub.dev. Depend on a tagged ref:

```yaml
dependencies:
  wireguard_dart:
    git:
      url: https://github.com/mysteriumnetwork/wireguard_dart.git
      ref: 0.9.13
```

The Flutter SDK version is pinned **exactly** (`environment: flutter: 3.44.7`), so a consuming app
must build on that version. It is also recorded in `.fvmrc` for [FVM](https://fvm.app).

## Usage

```dart
final wireguard = WireguardDart();

// Once per process, before anything else.
await wireguard.nativeInit();

// Generate the client keypair (persist the private key yourself).
final keys = await wireguard.generateKeyPair();

// Create/load the platform tunnel. `win32ServiceName` is Windows-only.
await wireguard.setupTunnel(
  bundleId: 'com.example.app.tun', // the packet-tunnel extension's bundle id
  tunnelName: 'Example VPN',
  win32ServiceName: 'ExampleVPNTunnel',
);

// Watch the tunnel state.
wireguard.statusStream().listen((status) => print('tunnel: $status'));

// Connect with a wg-quick style configuration.
await wireguard.connect(cfg: wgQuickConfig);

// Live counters (see "Tunnel statistics" below).
final stats = await wireguard.getTunnelStatistics();
print('rx=${stats?.totalDownload} tx=${stats?.totalUpload}');

await wireguard.disconnect();
```

## Platform setup

### Android

The library manifest declares `android.permission.POST_NOTIFICATIONS`, needed for the foreground
service notification on Android 13+ (API 33+). `connect()` does **not** hard-fail without it, but
the tunnel notification will be invisible. Use the helpers to prompt:

```dart
if (await wireguard.checkNotificationPermission() != NotificationPermission.granted) {
  final result = await wireguard.requestNotificationPermission();
  if (result == NotificationPermission.permanentlyDenied) {
    await wireguard.openAppNotificationSettings();
  }
}
```

### iOS and macOS

The host app must ship a **Packet Tunnel Provider** extension target whose principal class
subclasses `WireGuardTunnelProvider` (from the WireGuardKit pod) and forwards the base
implementations:

```swift
class PacketTunnelProvider: WireGuardTunnelProvider {
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        super.handleAppMessage(messageData, completionHandler: completionHandler)
    }
}
```

Forwarding `handleAppMessage` is **required for tunnel statistics** — that is the channel the
plugin queries. Declare the pod on the app target and let the extension target inherit search
paths from it:

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  pod 'WireGuardKit', :podspec => "https://raw.githubusercontent.com/mysteriumnetwork/wireguard-apple/0.5/WireGuardKit.podspec"

  target 'tun' do
    inherit! :search_paths
  end
end
```

The extension target needs the Network Extensions capability with `packet-tunnel-provider` in its
entitlements. The `bundleId` passed to `setupTunnel` is written to
`NETunnelProviderProtocol.providerBundleIdentifier`, so it must be the **extension's** bundle
identifier — it is also the key the plugin matches on when looking up an existing tunnel.

### Windows

The plugin starts the WireGuard tunnel as a **Windows service**, so the host process must be
elevated — `connect()` calls `CreateService`. `wireguard_svc.exe`, `tunnel.dll` and `wireguard.dll`
are bundled and copied next to the app executable at build time. `nativeInit()` also stops and
disables the `RemoteAccess` service, which conflicts with WireGuard routing.

## Tunnel statistics

`getTunnelStatistics()` returns `TunnelStatistics?` — `totalDownload` (rx), `totalUpload` (tx) and
`latestHandshake` in epoch milliseconds. Counters are cumulative for the session; `latestHandshake`
is `0` until the first handshake completes.

How each platform sources them:

| Platform | Mechanism | Wire format |
| --- | --- | --- |
| Android | `Backend.getStatistics(tunnel)` | JSON |
| iOS / macOS | `sendProviderMessage` to the extension, answered by `wgGetConfig` | UAPI text |
| Windows | The tunnel service's UAPI named pipe (`get=1`) | UAPI text |

UAPI text is parsed in Dart by `TunnelStatistics.fromUapi`, shared by both platforms that use it,
including the seconds + nanoseconds handshake fields. Notes worth knowing:

- **Contract.** Platform-level failures — "not connected", an unreadable pipe, a truncated
  response — return `null`. A platform with no implementation at all throws
  `MissingPluginException`, so a poller can stop permanently instead of retrying forever.
- **Cost.** On Apple platforms each call is an IPC round-trip that wakes the network extension; on
  Windows it opens a named pipe. Poll no faster than you need, and stop when disconnected.
- **Windows elevation.** The UAPI pipe is protected by an Administrators-only DACL, satisfied by
  the same elevation `connect()` already requires.

## API reference

| Method | Purpose |
| --- | --- |
| `nativeInit()` | Per-process native setup; on Windows also disables the conflicting `RemoteAccess` service |
| `generateKeyPair()` | Returns a `KeyPair` (`publicKey`, `privateKey`) |
| `setupTunnel({bundleId, tunnelName, win32ServiceName})` | Creates or loads the platform tunnel configuration |
| `connect({cfg})` | Starts the tunnel from a wg-quick style configuration |
| `disconnect()` | Stops the tunnel |
| `status()` | One-shot `ConnectionStatus` |
| `statusStream()` | Distinct `ConnectionStatus` updates |
| `checkTunnelConfiguration({bundleId, tunnelName})` | Whether a tunnel configuration already exists |
| `removeTunnelConfiguration({bundleId, tunnelName})` | Deletes the tunnel configuration |
| `getTunnelStatistics()` | Live byte counters and last handshake |
| `checkNotificationPermission()` | Android notification permission state |
| `requestNotificationPermission()` | Prompts for the Android notification permission |
| `openAppNotificationSettings()` | Opens the system notification settings |

`ConnectionStatus` is one of `connecting`, `connected`, `disconnecting`, `disconnected`, `unknown`
(the fallback for anything unrecognised).

## Development

All commands go through [FVM](https://fvm.app) so they use the pinned SDK. The `Makefile` wraps
the common ones:

```bash
make init      # flutter pub get
make generate  # build_runner (mockito mocks) + dart format
make analyze   # flutter analyze
make test      # flutter test
make check     # format + analyze + test, as CI runs it
```

The Dart test suite covers the platform-interface contract, the method-channel dispatch (including
which errors are swallowed and which propagate), the UAPI parser, and the models. Native code has
no test target, so Swift and C++ changes are verified by building `example/`:

```bash
cd example && flutter build ios --simulator --debug   # compiles the darwin plugin
cd example && flutter build windows --debug           # compiles the Windows plugin
```

CI runs `pub get`, codegen and the test suite on every PR, installing the SDK from `.fvmrc` so it
matches the exact pin in `pubspec.yaml`.

## Releasing

- Open a PR with the proposed changes:
  - Add `[major]` to the title for breaking changes
  - Add `[minor]` for new features
  - Otherwise it is a patch release — add nothing
- Once checks pass and the PR is approved, merge it
- Update `CHANGELOG.md` and tag the release manually (semantic-release from the title is disabled)
