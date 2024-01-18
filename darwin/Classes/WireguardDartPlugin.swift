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
    
    private var vpnManager: NETunnelProviderManager?
    
    var vpnStatus: NEVPNStatus {
        get {
            return vpnManager?.connection.status ?? NEVPNStatus.invalid
        }
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
#if os(iOS)
        let messenger = registrar.messenger()
#else
        let messenger = registrar.messenger
#endif
        let channel = FlutterMethodChannel(name: "wireguard_dart", binaryMessenger: messenger)
        
        let instance = WireguardDartPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let statusChannel = FlutterEventChannel(name: "wireguard_dart/status", binaryMessenger: messenger)
        statusChannel.setStreamHandler(ConnectionStatusObserver())
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
            guard let args = call.arguments as? Dictionary<String, Any>, args["bundleId"] != nil else {
                result(nativeFlutterError(message: "required argument: 'bundleId'"))
                return
            }
            guard let bundleId = args["bundleId"] as? String, !bundleId.isEmpty else {
                result(nativeFlutterError(message: "required argument: 'bundleId'"))
                return
            }
            guard let tunnelName = args["tunnelName"] as? String, !tunnelName.isEmpty else {
                result(nativeFlutterError(message: "required argument: 'tunnelName'"))
                return
            }
            Logger.main.debug("Tunnel bundle ID: \(bundleId), name: \(tunnelName)")
            Task {
                do {
                    vpnManager = try await setupProviderManager(bundleId: bundleId, tunnelName: tunnelName)
                    Logger.main.debug("Tunnel setup OK")
                    result("")
                } catch {
                    Logger.main.error("Tunnel setup ERROR: \(error)")
                    result(nativeFlutterError(message: "could not setup VPN tunnel: \(error)"))
                    return
                }
            }
        case "connect":
            Logger.main.debug("handle connect")
            let cfg: String
            if let args = call.arguments as? Dictionary<String, Any>,
               let argCfg = args["cfg"] as? String {
                cfg = argCfg
            } else {
                Logger.main.error("Required argument 'cfg' not provided")
                result(nativeFlutterError(message: "required argument: 'cfg'"))
                return
            }
            guard let mgr = vpnManager else {
                Logger.main.error("Tunnel not initialized, missing 'vpnManager'")
                result(nativeFlutterError(message: "tunnel not initialized, missing 'vpnManager'"))
                return
            }
            Logger.main.debug("Connection configuration: \(cfg)")
            Task {
                do {
                    try mgr.connection.startVPNTunnel(options: [
                        "cfg": cfg as NSObject
                    ])
                    Logger.main.debug("Start VPN tunnel OK")
                    result("")
                } catch {
                    Logger.main.error("Start VPN tunnel ERROR: \(error)")
                    result(nativeFlutterError(message: "could not start VPN tunnel: \(error)"))
                }
            }
        case "disconnect":
            guard let mgr = vpnManager else {
                Logger.main.error("Tunnel not initialized, missing 'vpnManager'")
                result(nativeFlutterError(message: "tunnel not initialized, missing 'vpnManager'"))
                return
            }
            Task {
                mgr.connection.stopVPNTunnel()
                Logger.main.debug("Stop tunnel OK")
                result("")
            }
        case "status":
            guard let _ = vpnManager else {
                Logger.main.error("Tunnel not initialized, missing 'vpnManager'")
                result(nativeFlutterError(message: "tunnel not initialized, missing 'vpnManager'"))
                return
            }
            Task {
                result(ConnectionStatus.fromNEVPNStatus(ns: vpnStatus).string())
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func setupProviderManager(bundleId: String, tunnelName: String) async throws -> NETunnelProviderManager {
        let mgrs = try await NETunnelProviderManager.loadAllFromPreferences()
        let existingMgr = mgrs.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleId
        })
        let mgr = existingMgr ?? NETunnelProviderManager()
        
        mgr.localizedDescription = tunnelName
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleId
        proto.serverAddress = "" // must be non-null
        mgr.protocolConfiguration = proto
        mgr.isEnabled = true
        
        try await mgr.saveToPreferences()
        
        return mgr
    }
    
}
