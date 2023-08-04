#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import Cocoa
#else
#error("Unsupported platform")
#endif

import WireGuardKit
import NetworkExtension
import os

public class WireguardDartPlugin: NSObject, FlutterPlugin {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: WireguardDartPlugin.self)
    )

    private var vpnManager: NETunnelProviderManager?
    private var statusChannel: FlutterEventChannel?

    var vpnStatus: NEVPNStatus {
        get {
            return vpnManager?.connection.status ?? NEVPNStatus.invalid
        }
    }

    init(registrar: FlutterPluginRegistrar) {
        statusChannel = FlutterEventChannel(name: "wireguard_dart.status", binaryMessenger: registrar.messenger)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(name: "wireguard_dart", binaryMessenger: messenger)

        let instance = WireguardDartPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "generateKeyPair":
            let privateKey = PrivateKey()
            let privateKeyResponse: [String: Any] = [
                "privateKey": privateKey.base64Key,
                "publicKey": privateKey.publicKey.base64Key,
            ]
            result(privateKeyResponse)
        case "setupTunnel":
            Self.logger.debug("handle setupTunnel")
            guard let args = call.arguments as? Dictionary<String, Any>, args["bundleId"] != nil else {
                result(FlutterError.init(code: "NATIVE_ERR", message: "required argument: 'bundleId'", details: nil))
                return
            }
            guard let bundleId = args["bundleId"] as? String, !bundleId.isEmpty else {
                result(FlutterError.init(code: "NATIVE_ERR", message: "required argument: 'bundleId'", details: nil))
                return
            }
            Self.logger.debug("Tunnel bundle ID: \(bundleId)")
            Task {
                do {
                    vpnManager = try await setupProviderManager(bundleId: bundleId)
                    statusChannel!.setStreamHandler(ConnectionStatusObserver(vpnManager: vpnManager!))
                    Self.logger.debug("Tunnel setup OK")
                    result("")
                } catch {
                    Self.logger.error("Tunnel setup ERROR: \(error)")
                    result(
                        FlutterError.init(
                            code: "NATIVE_ERR", message: "could not setup VPN tunnel: \(error)", details: nil))
                    return
                }
            }
        case "connect":
            Self.logger.debug("handle connect")
            let cfg: String
            if let args = call.arguments as? Dictionary<String, Any>,
               let argCfg = args["cfg"] as? String {
                cfg = argCfg
            } else {
                Self.logger.error("Required argument 'cfg' not provided")
                result(FlutterError.init(code: "NATIVE_ERR", message: "required argument: 'cfg'", details: nil))
                return
            }
            guard let mgr = vpnManager else {
                Self.logger.error("Tunnel not initialized, missing 'vpnManager'")
                result(FlutterError.init(code: "NATIVE_ERR", message: "tunnel not initialized, missing 'vpnManager'", details: nil))
                return
            }
            Self.logger.debug("Connection configuration: \(cfg)")
            Task {
                do {
                    try mgr.connection.startVPNTunnel(options: [
                        "cfg": cfg as NSObject
                    ])
                    Self.logger.debug("Start VPN tunnel OK")
                    result("")
                } catch {
                    Self.logger.error("Start VPN tunnel ERROR: \(error)")
                    result(
                        FlutterError.init(
                            code: "NATIVE_ERR", message: "could not start VPN tunnel: \(error)", details: nil))
                }
            }
        case "disconnect":
            guard let mgr = vpnManager else {
                Self.logger.error("Tunnel not initialized, missing 'vpnManager'")
                result(FlutterError.init(code: "NATIVE_ERR", message: "tunnel not initialized, missing 'vpnManager'", details: nil))
                return
            }
            Task {
                mgr.connection.stopVPNTunnel()
                Self.logger.debug("Stop tunnel OK")
                result("")
            }
        case "status":
            guard let mgr = vpnManager else {
                Self.logger.error("Tunnel not initialized, missing 'vpnManager'")
                result(FlutterError.init(code: "NATIVE_ERR", message: "tunnel not initialized, missing 'vpnManager'", details: nil))
                return
            }
            Task {
                let mappedStatus: String = {
                    switch vpnStatus {
                    case .connected: return "connected"
                    case .disconnected:return  "disconnected"
                    case .connecting: return "connecting"
                    case .disconnecting: return "disconnecting"
                    default: return "unknown"
                    }
                }()
                result(["status": mappedStatus])
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func setupProviderManager(bundleId: String) async throws -> NETunnelProviderManager {
        let mgrs = await fetchManagers()
        let existingMgr = mgrs.first(where: { $0.localizedDescription == "Mysterium VPN" })
        let mgr = existingMgr ?? NETunnelProviderManager()

        mgr.localizedDescription = "Mysterium VPN"
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleId
        proto.serverAddress = "127.0.0.1"  // Fake address
        mgr.protocolConfiguration = proto
        mgr.isEnabled = true

        try await saveManager(mgr: mgr)
        return mgr
    }

    func fetchManagers() async -> [NETunnelProviderManager] {
        return await withCheckedContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                continuation.resume(returning: (managers ?? []))
            }
        }
    }

    func saveManager(mgr: NETunnelProviderManager) async throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            mgr.saveToPreferences { error in
                if let error: Error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}



