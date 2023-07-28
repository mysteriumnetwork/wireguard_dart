//
//  PacketTunnelProvider.swift
//  WireguardExtension
//
//  Created by Tadas Krivickas on 2022-11-15.
//

import NetworkExtension
import WireGuardKit
import os

class PacketTunnelProvider: WireGuardTunnelProvider {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PacketTunnelProvider.self)
    )

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            let level: OSLogType
            switch (logLevel) {
            case .verbose:
                level = OSLogType.debug
            case .error:
                level = OSLogType.error
            }
            Self.logger.log(level: level, "\(message)")
        }
    }()

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        super.startTunnel(options: options, completionHandler: completionHandler)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        super.stopTunnel(with: reason, completionHandler: completionHandler)
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        super.handleAppMessage(messageData, completionHandler: completionHandler)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        super.sleep(completionHandler: completionHandler)
    }
    
    override func wake() {
        super.wake()
    }
}
