package network.mysterium.wireguard_dart


import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

import android.app.Activity
import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.content.Context
import android.util.Log
import com.beust.klaxon.Klaxon
import com.wireguard.android.backend.*
import com.wireguard.crypto.KeyPair
import kotlinx.coroutines.*


import kotlinx.coroutines.launch
import java.io.ByteArrayInputStream

/** WireguardDartPlugin */

const val PERMISSIONS_REQUEST_CODE = 10014
const val METHOD_CHANNEL_NAME = "wireguard_dart"

class WireguardDartPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var tunnelName: String
    private val futureBackend = CompletableDeferred<Backend>()
    private val scope = CoroutineScope(Job() + Dispatchers.Main.immediate)
    private var backend: Backend? = null
    private var havePermission = false
    private lateinit var context: Context
    private var activity: Activity? = null
    private var config: com.wireguard.config.Config? = null
    private var tunnel: WireguardTunnel? = null
    private lateinit var status: ConnectionStatus

    companion object {
        const val TAG = "MainActivity"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        havePermission =
            (requestCode == PERMISSIONS_REQUEST_CODE) && (resultCode == Activity.RESULT_OK)
        return havePermission
    }

    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        this.activity = activityPluginBinding.activity as FlutterActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        this.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {
        this.activity = activityPluginBinding.activity as FlutterActivity
    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL_NAME)
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
            "generateKeyPair" -> generateKeyPair(result)
            "setupTunnel" -> setupTunnel(call.argument<String>("bundleId").toString(), result)
            "connect" -> connect(call.argument<String>("cfg").toString(), result)
            "disconnect" -> disconnect(result)
            "status" -> status(result)
            "statistics" -> statistics(result)
            else -> flutterNotImplemented(result)
        }
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

    private fun setupTunnel(bundleId: String, result: Result) {
        scope.launch(Dispatchers.IO) {
            if (Tunnel.isNameInvalid(bundleId)) {
                flutterError(result, "Invalid Name")
                return@launch
            }
            tunnelName = bundleId
            checkPermission()
            tunnel = WireguardTunnel(tunnelName)
            status = when (backend?.getState(tunnel!!)) {
                Tunnel.State.UP -> ConnectionStatus.connected
                Tunnel.State.DOWN -> ConnectionStatus.disconnected
                else -> ConnectionStatus.unknown
            }
            result.success(null)
        }
    }

    private fun connect(cfg: String, result: Result) {
        val tun = tunnel ?: run {
            result.error("err_setup_tunnel", "Tunnel is not initialized", null)
            return
        }
        scope.launch(Dispatchers.IO) {
            try {
                if (!havePermission) {
                    checkPermission()
                    throw Exception("Permissions are not given")
                }
                val inputStream = ByteArrayInputStream(cfg.toByteArray())
                config = com.wireguard.config.Config.parse(inputStream)
                futureBackend.await().setState(tun, Tunnel.State.UP, config);
                flutterSuccess(result, "")
            } catch (e: BackendException) {
                Log.e(TAG, "Connect - BackendException - ERROR - ${e.reason}", e)
                flutterError(result, e.reason.toString())
            } catch (e: Throwable) {
                Log.e(TAG, "Connect - Can't connect to tunnel: $e", e)
                flutterError(result, e.message.toString())
            }
        }
    }

    private fun disconnect(result: Result) {
        val tun = tunnel ?: run {
            result.error("err_setup_tunnel", "Tunnel is not initialized", null)
            return
        }
        scope.launch(Dispatchers.IO) {
            try {
                if (futureBackend.await().runningTunnelNames.isEmpty()) {
                    throw Exception("Tunnel is not running")
                }
                futureBackend.await().setState(tun, Tunnel.State.DOWN, config)
                flutterSuccess(result, "")
            } catch (e: BackendException) {
                Log.e(TAG, "Disconnect - BackendException - ERROR - ${e.reason}", e)
                flutterError(result, e.reason.toString())
            } catch (e: Throwable) {
                Log.e(TAG, "Disconnect - Can't disconnect from tunnel: ${e.message}")
                flutterError(result, e.message.toString())
            }
        }
    }


    private fun statistics(result: Result) {
        val tun = tunnel ?: run {
            result.error("err_setup_tunnel", "Tunnel is not initialized", null)
            return
        }
        scope.launch(Dispatchers.IO) {
            try {
                val statistics = futureBackend.await().getStatistics(tun)
                val stats = Stats(statistics.totalRx(), statistics.totalTx())

                flutterSuccess(
                    result, Klaxon().toJsonString(
                        stats
                    )
                )
                Log.i(TAG, "Statistics - ${stats.totalDownload} ${stats.totalUpload}")

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
        if (tunnel == null) {
            flutterError(result, "Tunnel has not been initialized")
            return
        }
        val status = when (backend?.getState(tunnel!!)) {
            Tunnel.State.DOWN -> ConnectionStatus.disconnected
            Tunnel.State.UP -> ConnectionStatus.connected
            else -> ConnectionStatus.unknown
        }
        result.success(hashMapOf("status" to status.name))
    }
}

typealias StateChangeCallback = (Tunnel.State) -> Unit

class WireguardTunnel(
    private val name: String, private val onStateChanged: StateChangeCallback? = null
) : Tunnel {

    override fun getName() = name

    override fun onStateChange(newState: Tunnel.State) {
        onStateChanged?.invoke(newState)
    }

}

class Stats(
    val totalDownload: Long,
    val totalUpload: Long,
)


