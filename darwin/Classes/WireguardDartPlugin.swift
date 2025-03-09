import NetworkExtension
import WireGuardKit
import os

#if os(iOS)
    import Flutter
    import UIKit
#elseif os(macOS)
    import Cocoa
    import FlutterMacOS
#else
    #error("Unsupported platform")
#endif

public class WireguardDartPlugin: NSObject, FlutterPlugin {
    private var vpnManager: NETunnelProviderManager?
    var vpnStatus: NEVPNStatus {
        vpnManager?.connection.status ?? NEVPNStatus.invalid
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
            let messenger = registrar.messenger()
        #else
            let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(
            name: "wireguard_dart", binaryMessenger: messenger)

        let instance = WireguardDartPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let statusChannel = FlutterEventChannel(
            name: "wireguard_dart/status", binaryMessenger: messenger)
        statusChannel.setStreamHandler(ConnectionStatusObserver())
    }

    public func handle(
        _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
        switch call.method {
        case "nativeInit":
            result("")
        case "generateKeyPair":
            let privateKey = PrivateKey()
            let privateKeyResponse: [String: Any] = [
                "privateKey": privateKey.base64Key,
                "publicKey": privateKey.publicKey.base64Key,
            ]
            result(privateKeyResponse)
        case "setupTunnel":
            Logger.main.debug("handle setupTunnel")
            guard let args = call.arguments as? [String: Any],
                args["bundleId"] != nil
            else {
                result(
                    nativeFlutterError(message: "required argument: 'bundleId'")
                )
                return
            }
            guard let bundleId = args["bundleId"] as? String, !bundleId.isEmpty
            else {
                result(
                    nativeFlutterError(message: "required argument: 'bundleId'")
                )
                return
            }
            guard let tunnelName = args["tunnelName"] as? String,
                !tunnelName.isEmpty
            else {
                result(
                    nativeFlutterError(
                        message: "required argument: 'tunnelName'"))
                return
            }
            Logger.main.debug(
                "Tunnel bundle ID: \(bundleId), name: \(tunnelName)")
            Task {
                do {
                    vpnManager = try await setupProviderManager(
                        bundleId: bundleId, tunnelName: tunnelName)
                    Logger.main.debug("Tunnel setup OK")
                    result("")
                } catch {
                    Logger.main.error("Tunnel setup ERROR: \(error)")
                    result(
                        nativeFlutterError(
                            message: "could not setup VPN tunnel: \(error)"))
                    return
                }
            }
        case "connect":
            Logger.main.debug("handle connect")
            let cfg: String
            if let args = call.arguments as? [String: Any],
                let argCfg = args["cfg"] as? String
            {
                cfg = argCfg
            } else {
                Logger.main.error("Required argument 'cfg' not provided")
                result(nativeFlutterError(message: "required argument: 'cfg'"))
                return
            }
            guard let mgr = vpnManager else {
                Logger.main.error(
                    "Tunnel not initialized, missing 'vpnManager'")
                result(
                    nativeFlutterError(
                        message: "tunnel not initialized, missing 'vpnManager'")
                )
                return
            }
            Logger.main.debug("Connection configuration: \(cfg)")
            Task {
                do {
                    if !mgr.isEnabled {
                        mgr.isEnabled = true
                        try await mgr.saveToPreferences()
                        try await mgr.loadFromPreferences()

                    }

                    try mgr.connection.startVPNTunnel(options: [
                        "cfg": cfg as NSObject
                    ])
                    Logger.main.debug("Start VPN tunnel OK")
                    result("")
                } catch let error as NEVPNError {
                    switch error.code {
                    case .configurationInvalid:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Configuration is invalid")
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Configuration is invalid"
                            ))
                    case .configurationDisabled:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Configuration is disabled")
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Configuration is disabled"
                            ))
                    case .connectionFailed:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Connection failed")
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Connection failed"
                            ))
                    case .configurationStale:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Configuration is stale")
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Configuration is stale"
                            ))
                    case .configurationReadWriteFailed:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Configuration read/write failed"
                        )
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Configuration read/write failed"
                            ))
                    case .configurationUnknown:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Configuration unknown")
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Configuration unknown"
                            ))
                    @unknown default:
                        Logger.main.error(
                            "Start VPN tunnel ERROR: Unknown error")
                        result(
                            nativeFlutterError(
                                message:
                                    "could not start VPN tunnel: Unknown error")
                        )
                    }
                } catch {
                    Logger.main.error("Start VPN tunnel ERROR: \(error)")
                    result(
                        nativeFlutterError(
                            message: "could not start VPN tunnel: \(error)"))
                }
            }
        case "disconnect":
            guard let mgr = vpnManager else {
                Logger.main.error(
                    "Tunnel not initialized, missing 'vpnManager'")
                result(
                    nativeFlutterError(
                        message: "tunnel not initialized, missing 'vpnManager'")
                )
                return
            }
            Task {
                mgr.connection.stopVPNTunnel()
                Logger.main.debug("Stop tunnel OK")
                result("")
            }
        case "status":
            if vpnManager != nil {
                Task {
                    result(
                        ConnectionStatus.fromNEVPNStatus(status: vpnStatus)
                            .string())
                }
            } else {
                result(ConnectionStatus.unknown.string())
            }
        case "checkTunnelConfiguration":
            guard let args = call.arguments as? [String: Any],
                let bundleId = args["bundleId"] as? String, !bundleId.isEmpty
            else {
                result(
                    nativeFlutterError(message: "required argument: 'bundleId'")
                )
                return
            }
            guard let args = call.arguments as? [String: Any],
                let tunnelName = args["tunnelName"] as? String,
                !tunnelName.isEmpty
            else {
                result(
                    nativeFlutterError(
                        message: "required argument: 'tunnelName'")
                )
                return
            }
            checkTunnelConfiguration(bundleId: bundleId, tunnelName: tunnelName)
            { manager in
                if let vpnManager = manager {
                    self.vpnManager = vpnManager
                    Logger.main.debug("Tunnel is set up and existing")
                    result(true)
                } else {
                    Logger.main.debug("Tunnel is not set up")
                    result(false)
                }
            }
        case "removeTunnelConfiguration":
            guard let args = call.arguments as? [String: Any],
                let bundleId = args["bundleId"] as? String, !bundleId.isEmpty,
                let tunnelName = args["tunnelName"] as? String,
                !tunnelName.isEmpty
            else {
                result(
                    nativeFlutterError(
                        message:
                            "required arguments: 'bundleId' and 'tunnelName'"))
                return
            }
            Task {
                do {
                    try await removeTunnelConfiguration(
                        bundleId: bundleId, tunnelName: tunnelName)
                    result(true)
                } catch {
                    result(
                        nativeFlutterError(
                            message:
                                "Error removing tunnel configuration: \(error.localizedDescription)"
                        ))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func setupProviderManager(bundleId: String, tunnelName: String) async throws
        -> NETunnelProviderManager
    {
        let mgrs = try await NETunnelProviderManager.loadAllFromPreferences()
        let existingMgr = mgrs.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == bundleId
        })
        let mgr = existingMgr ?? NETunnelProviderManager()

        try await configureManager(
            mgr: mgr, bundleId: bundleId, tunnelName: tunnelName)

        return mgr
    }

    func configureManager(
        mgr: NETunnelProviderManager, bundleId: String, tunnelName: String
    ) async throws {
        mgr.localizedDescription = tunnelName
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleId
        proto.serverAddress = ""  // must be non-null
        mgr.protocolConfiguration = proto
        mgr.isEnabled = true

        try await mgr.saveToPreferences()
        try await mgr.loadFromPreferences()
    }

    func isVpnManagerConfigured(bundleId: String, tunnelName: String)
        async throws -> NETunnelProviderManager?
    {
        // Load all managers from preferences
        let mgrs = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existingMgr = mgrs.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == bundleId
        }) {
            return existingMgr
        }
        return nil
    }

    func checkTunnelConfiguration(
        bundleId: String, tunnelName: String,
        result: @escaping (NETunnelProviderManager?) -> Void
    ) {
        Task {
            do {
                let mgr = try await isVpnManagerConfigured(
                    bundleId: bundleId, tunnelName: tunnelName)
                if let mgr = mgr {
                    try await configureManager(
                        mgr: mgr, bundleId: bundleId, tunnelName: tunnelName)
                }
                result(mgr)
            } catch {
                Logger.main.error(
                    "Error checking tunnel configuration: \(error)")
                result(nil)
            }
        }
    }

    func removeTunnelConfiguration(bundleId: String, tunnelName: String)
        async throws
    {
        let mgrs = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existingMgr = mgrs.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == bundleId
                && $0.localizedDescription == tunnelName
        }) {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                existingMgr.removeFromPreferences { error in
                    if let error = error {
                        Logger.main.error(
                            "Error removing tunnel configuration: \(error)")
                        continuation.resume(throwing: error)
                    } else {
                        Logger.main.debug(
                            "Tunnel configuration removed successfully")
                        self.vpnManager = nil
                        continuation.resume(returning: ())
                    }
                }
            }
        } else {
            Logger.main.debug("Tunnel configuration not found")
            throw NSError(
                domain: "WireguardDartPlugin", code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey: "Tunnel configuration not found"
                ])
        }
    }
}
