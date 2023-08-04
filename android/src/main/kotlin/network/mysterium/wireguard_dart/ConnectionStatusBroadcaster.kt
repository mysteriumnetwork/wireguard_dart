package network.mysterium.wireguard_dart

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler

class ConnectionStatusBroadcaster : StreamHandler {

    private var eventSink: EventSink? = null
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(status: ConnectionStatus) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(hashMapOf("status" to status.name))
        }
    }
}