//
//  PacketTunnelProvider.swift
//  WireguardExtension
//
//  Created by Tadas Krivickas on 2022-11-15.
//

import NetworkExtension
import WireGuardKit

class PacketTunnelProvider: WireGuardTunnelProvider {

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
