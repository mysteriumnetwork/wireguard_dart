import Cocoa
import FlutterMacOS
import NetworkExtension
import WireGuardKit

public class ConnectionStatusObserver: NSObject, FlutterStreamHandler {

  private var _eventSink: FlutterEventSink?
  private var _vpnManager: NETunnelProviderManager

  private var pIsRunning: Bool = false
  var isRunning: Bool {
    pIsRunning
  }

  init(vpnManager: NETunnelProviderManager) {
    _vpnManager = vpnManager
  }

  public func _statusChanged(_: Notification?) {
    guard let _eventSink = _eventSink else {
      return
    }
      _eventSink(ConnectionStatus.fromNEVPNStatus(ns: _vpnManager.connection.status).string())
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self._eventSink = events

    if !pIsRunning {
      NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NEVPNStatusDidChange,
        object: nil,
        queue: OperationQueue.main,
        using: _statusChanged
      )
    }

    pIsRunning = true

    // Send the initial data.

    // No errors.
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    pIsRunning = false

    NotificationCenter.default.removeObserver(self)

    _eventSink = nil

    return nil
  }
}
