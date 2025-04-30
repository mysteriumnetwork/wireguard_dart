package network.mysterium.wireguard_dart


import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import com.beust.klaxon.Klaxon
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.BackendException
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.crypto.KeyPair
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.ByteArrayInputStream

const val PERMISSIONS_REQUEST_CODE = 10014

class WireguardDartPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var statusChannel: EventChannel
    private lateinit var statusBroadcaster: ConnectionStatusBroadcaster
    private val futureBackend = CompletableDeferred<Backend>()
    private val scope = CoroutineScope(Job() + Dispatchers.Main.immediate)
    private var backend: Backend? = null
    private var havePermission = false
    private lateinit var context: Context
    private var activity: Activity? = null
    private var config: com.wireguard.config.Config? = null
    private var tunnel: WireguardTunnel? = null
    private var tunnelName: String? = null
    private var permissionsResultCallback: Result? = null
    private var status: ConnectionStatus = ConnectionStatus.disconnected
        set(value) {
            field = value
            if (::statusBroadcaster.isInitialized) {
                statusBroadcaster.send(value)
            }
        }

    companion object {
        const val TAG = "MainActivity"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            havePermission = resultCode == Activity.RESULT_OK
            if (havePermission) {
                permissionsResultCallback?.success(null)
            } else {
                permissionsResultCallback?.error(
                    "err_setup_tunnel",
                    "Permissions are not given",
                    null
                )

            }
        }
        return havePermission
    }

    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        if (activityPluginBinding.activity is FlutterFragmentActivity) {
            this.activity = activityPluginBinding.activity as FlutterFragmentActivity
        } else if (activityPluginBinding.activity is FlutterActivity) {
            this.activity = activityPluginBinding.activity as FlutterActivity
        }
        activityPluginBinding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        this.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {
        if (activityPluginBinding.activity is FlutterFragmentActivity) {
            this.activity = activityPluginBinding.activity as FlutterFragmentActivity
        } else if (activityPluginBinding.activity is FlutterActivity) {
            this.activity = activityPluginBinding.activity as FlutterActivity
        }
        this.activity = activityPluginBinding.activity as FlutterActivity
    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "wireguard_dart")
        statusChannel = EventChannel(flutterPluginBinding.binaryMessenger, "wireguard_dart/status")
        statusBroadcaster = ConnectionStatusBroadcaster()
        statusChannel.setStreamHandler(statusBroadcaster)
        context = flutterPluginBinding.applicationContext

        scope.launch(Dispatchers.IO) {
            try {
                backend = createBackend()
                futureBackend.complete(backend!!)
            } catch (e: Throwable) {
                Log.e(TAG, Log.getStackTraceString(e))
            }
        }
        channel.setMethodCallHandler(this)
    }

    private fun createBackend(): Backend {
        if (backend == null) {
            backend = GoBackend(context)
        }
        return backend as Backend
    }

    private fun flutterSuccess(result: Result, o: Any) {
        scope.launch(Dispatchers.Main) {
            result.success(o)
        }
    }

    private fun flutterError(result: Result, error: String) {
        scope.launch(Dispatchers.Main) {
            result.error(error, null, null)
        }
    }

    private fun flutterNotImplemented(result: Result) {
        scope.launch(Dispatchers.Main) {
            result.notImplemented()
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "nativeInit" -> result.success("")
            "generateKeyPair" -> generateKeyPair(result)
            "setupTunnel" -> setupTunnel(
                call.argument<String>("tunnelName").toString(),
                result
            )

            "checkTunnelConfiguration" -> {
                checkTunnelConfiguration(call.argument<String>("tunnelName").toString(), result)
            }

            "connect" -> connect(call.argument<String>("cfg").toString(), result)
            "disconnect" -> disconnect(result)
            "status" -> status(result)
            "tunnelStatistics" -> statistics(result)
            else -> flutterNotImplemented(result)
        }
    }

    private fun checkTunnelConfiguration(tunnelName: String, result: Result) {
        val intent = GoBackend.VpnService.prepare(this.activity)
        havePermission = intent == null
        if (havePermission) {
            initTunnel(tunnelName)
        }
        return result.success(havePermission)
    }

    private fun generateKeyPair(result: Result) {
        val keyPair = KeyPair()
        result.success(
            hashMapOf(
                "privateKey" to keyPair.privateKey.toBase64(),
                "publicKey" to keyPair.publicKey.toBase64()
            )
        )
    }

    private fun setupTunnel(tunnelName: String, result: Result) {
        scope.launch(Dispatchers.IO) {
            if (Tunnel.isNameInvalid(tunnelName)) {
                flutterError(result, "Tunnel name is invalid")
                return@launch
            }
            permissionsResultCallback = result
            checkPermission()
            initTunnel(tunnelName)
        }
    }

    private fun initTunnel(tunnelName: String) {
        this.tunnelName = tunnelName
        tunnel = WireguardTunnel(tunnelName) { state ->
            status = ConnectionStatus.fromTunnelState(state)
        }
        status = ConnectionStatus.fromTunnelState(backend?.getState(tunnel!!))
    }


    private fun connect(cfg: String, result: Result) {
        val tun = tunnel ?: run {
            result.error("err_setup_tunnel", "Tunnel is not initialized", null)
            return
        }
        status = ConnectionStatus.connecting
        scope.launch(Dispatchers.IO) {
            try {
                if (!havePermission) {
                    checkPermission()
                    throw Exception("Permissions are not given")
                }
                val inputStream = ByteArrayInputStream(cfg.toByteArray())
                config = com.wireguard.config.Config.parse(inputStream)
                futureBackend.await().setState(tun, Tunnel.State.UP, config)
                flutterSuccess(result, "")
            } catch (e: Throwable) {
                Log.e(TAG, "Connect - Can't connect to tunnel: $e", e)
                status = queryStatus()
                flutterError(result, e.message.toString())
            }
        }
    }

    private fun disconnect(result: Result) {
        val tun = tunnel ?: run {
            result.error("err_setup_tunnel", "Tunnel is not initialized", null)
            return
        }
        status = ConnectionStatus.disconnecting
        scope.launch(Dispatchers.IO) {
            try {
                if (futureBackend.await().runningTunnelNames.isEmpty()) {
                    throw Exception("Tunnel is not running")
                }
                futureBackend.await().setState(tun, Tunnel.State.DOWN, config)
                flutterSuccess(result, "")
            } catch (e: Throwable) {
                Log.e(TAG, "Disconnect - Can't disconnect from tunnel: ${e.message}")
                status = queryStatus()
                flutterError(result, e.message.toString())
            }
        }
    }


    private fun statistics(result: Result) {
        val tunnel =
            tunnel ?: return result.error("err_setup_tunnel", "Tunnel is not initialized", null)
        scope.launch(Dispatchers.IO) {
            try {
                val statistics = futureBackend.await().getStatistics(tunnel)
                var latestHandshake = 0L

                for (key in statistics.peers()) {
                    val peerStats = statistics.peer(key)
                    if (peerStats !== null && peerStats.latestHandshakeEpochMillis > latestHandshake) {
                        latestHandshake = peerStats.latestHandshakeEpochMillis
                    }
                }
                val stats =
                    TunnelStatistics(statistics.totalRx(), statistics.totalTx(), latestHandshake)

                flutterSuccess(result, Klaxon().toJsonString(stats))
                Log.i(
                    TAG,
                    "Statistics - ${stats.totalDownload} ${stats.totalUpload} ${stats.latestHandshake}"
                )

            } catch (e: BackendException) {
                Log.e(TAG, "Statistics - BackendException - ERROR - ${e.reason} ", e)
                flutterError(result, e.reason.toString())
            } catch (e: Throwable) {
                Log.e(TAG, "Statistics - Can't get stats: ${e.message}", e)
                flutterError(result, e.message.toString())
            }
        }
    }

    private fun checkPermission() {
        val intent = GoBackend.VpnService.prepare(this.activity)
        if (intent != null) {
            havePermission = false
            this.activity?.startActivityForResult(intent, PERMISSIONS_REQUEST_CODE)
        } else {
            havePermission = true
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun status(result: Result) {
        val status = queryStatus()
        result.success(status.name)
    }

    private fun queryStatus(): ConnectionStatus {
        if (tunnel == null) {
            return ConnectionStatus.unknown
        }
        return when (backend?.getState(tunnel!!)) {
            Tunnel.State.DOWN -> ConnectionStatus.disconnected
            Tunnel.State.UP -> ConnectionStatus.connected
            else -> ConnectionStatus.unknown
        }
    }
}

typealias StateChangeCallback = (Tunnel.State) -> Unit

class WireguardTunnel(
    private val name: String,
    private val onStateChanged: StateChangeCallback? = null
) : Tunnel {

    override fun getName() = name

    override fun onStateChange(newState: Tunnel.State) {
        onStateChanged?.invoke(newState)
    }

}

class TunnelStatistics(
    val totalDownload: Long,
    val totalUpload: Long,
    val latestHandshake: Long,
)


