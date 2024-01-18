#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import Cocoa
#else
#error("Unsupported platform")
#endif

import NetworkExtension
import WireGuardKit
import os

class ConnectionStatusObserver: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    private var isRunning: Bool = false
    
    public func _statusChanged(n: Notification?) {
        guard let conn = n?.object as? NEVPNConnection else {
            return
        }
        guard let eventSink = eventSink else {
            return
        }
        let newStatus = ConnectionStatus.fromNEVPNStatus(ns: conn.status)
        
        Logger.main.debug("VPN status changed: \(newStatus.string())")
        eventSink(newStatus.string())
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        if !isRunning {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NEVPNStatusDidChange,
                object: nil,
                queue: OperationQueue.main,
                using: _statusChanged
            )
        }
        
        isRunning = true
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        isRunning = false
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        return nil
    }
}