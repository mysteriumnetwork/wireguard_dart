// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "wireguard_dart",
  platforms: [
    .iOS("15.0"),
    .macOS("12.0")
  ],
  products: [
    .library(name: "wireguard-dart", targets: ["wireguard_dart"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/mysteriumnetwork/wireguard-apple.git", from: "0.6.0")
  ],
  targets: [
    .target(
      name: "wireguard_dart",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "WireGuardKit", package: "wireguard-apple")
      ]
    )
  ]
)
