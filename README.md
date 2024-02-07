# wireguard_dart

A flutter plugin to setup and control VPN connection via [Wireguard](https://www.wireguard.com/) tunnel.

It includes [Wireguard implementation for the corresponding OS](https://www.wireguard.com/embedding/) (WireGuardKit for darwin, com.wireguard.android:tunnel for android, etc.) and does not require any additional dependencies.


|             | Android | iOS   | Linux | macOS | Windows     |
|-------------|---------|-------|-------|-------|-------------|
| **Support** | 21+     | 15.0+ | TBD   | 12+   | 10+         |

## Usage

To use this plugin, add `wireguard_dart` as a [dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).

## Development

- Create a PR with proposed changes:
  - Add [major] to the title if it has breaking changes
  - Add [minor] if it has new features
  - Otherwise, it's a patch release, don't add anything
- After status checks are passed and PR is approved, merge it
- ~~Changes are automatically released as a new semantic version based on tags in the title~~ Changelog should be provided and committed manually
