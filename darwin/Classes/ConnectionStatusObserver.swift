import Cocoa
import FlutterMacOS
import NetworkExtension
import WireGuardKit

public class ConnectionStatusObserver: NSObject, FlutterStreamHandler {

  private var _sink: FlutterEventSink?
  private var _vpnManager: NETunnelProviderManager

  private var pIsRunning: Bool = false
  var isRunning: Bool {
    pIsRunning
  }

  init(vpnManager: NETunnelProviderManager) {
    _vpnManager = vpnManager
  }

  public func _statusChanged(_: Notification?) {
      guard let sink = _sink else {
                  return
              }
    let status = _vpnManager.connection.status
      let mappedStatus: Dictionary<String, String> = {
      switch status {
      case .connected:
        return ["status": "connected"]
      case .disconnected:
        return ["status": "connected"]
      case .connecting:
        return ["status": "connecting"]
      case .disconnecting:
        return ["status": "disconnecting"]
      default:
        return ["status": "unknown"]
      }
    }()
      sink(mappedStatus)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    _sink = events

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

    _sink = nil

    return nil
  }
}
