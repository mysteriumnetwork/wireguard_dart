#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import Cocoa
import FlutterMacOS
#else
#error("Unsupported platform")
#endif

import NetworkExtension
import os
import WireGuardKit

class ConnectionStatusObserver: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var isRunning: Bool = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NEVPNStatusDidChange,
            object: nil,
            queue: OperationQueue.main,
            using: handleStatusChanged
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func handleStatusChanged(notification: Notification?) {
        guard let conn = notification?.object as? NEVPNConnection else {
            return
        }
        let newStatus = ConnectionStatus.fromNEVPNStatus(status: conn.status)

        Logger.main.debug("VPN status changed: \(newStatus.string())")
        eventSink?(newStatus.string())
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
