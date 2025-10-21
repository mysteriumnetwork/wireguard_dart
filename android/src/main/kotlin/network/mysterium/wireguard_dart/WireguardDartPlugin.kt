package network.mysterium.wireguard_dart

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.beust.klaxon.Klaxon
import com.wireguard.android.backend.Backend
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
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

const val PERMISSIONS_REQUEST_CODE = 10014

class WireguardDartPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var statusChannel: EventChannel
    private lateinit var statusBroadcaster: ConnectionStatusBroadcaster

    private val scope = CoroutineScope(Job() + Dispatchers.Main.immediate)
    private var backend: Backend? = null
    private var havePermission = false
    private lateinit var context: Context
    private var activity: Activity? = null
    private var tunnel: WireguardTunnel? = null
    private var tunnelName: String? = null
    private var permissionsResultCallback: MethodChannel.Result? = null

    private lateinit var notificationHelper: NotificationHelper
    private var activityBinding: ActivityPluginBinding? = null

    private var status: ConnectionStatus = ConnectionStatus.disconnected
        set(value) {
            field = value
            if (::statusBroadcaster.isInitialized) {
                statusBroadcaster.send(value)
            }
        }

    private lateinit var notificationPermissionManager: NotificationPermissionManager

    companion object {
        private const val TAG = "WireguardDartPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        notificationPermissionManager = NotificationPermissionManager()
        channel = MethodChannel(binding.binaryMessenger, "wireguard_dart")
        statusChannel = EventChannel(binding.binaryMessenger, "wireguard_dart/status")
        statusBroadcaster = ConnectionStatusBroadcaster()
        statusChannel.setStreamHandler(statusBroadcaster)
        context = binding.applicationContext

        // Initialize WireguardBackend singleton before usage
        WireguardBackend.init(context, scope)

        // Subscribe plugin status Channel to backend statusFlow (single collector)
        scope.launch {
            WireguardBackend.instance.statusFlow.collect { s ->
                status = s
            }
        }

        // Initialize Notification channel for Android O+
        NotificationHelper.initNotificationChannel(context)
        notificationHelper = NotificationHelper(context)

        // Launch backend creation
        scope.launch(Dispatchers.IO) {
            try {
                backend = GoBackend(context)
            } catch (e: Throwable) {
                Log.e(TAG, "createBackend error", e)
            }
        }

        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // Activity aware handling - permissions
    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        this.activity = when (activityPluginBinding.activity) {
            is FlutterFragmentActivity -> activityPluginBinding.activity as FlutterFragmentActivity
            is FlutterActivity -> activityPluginBinding.activity as FlutterActivity
            else -> null
        }
        activityPluginBinding.addRequestPermissionsResultListener(notificationPermissionManager)
        activityPluginBinding.addActivityResultListener(this)
        activityBinding = activityPluginBinding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(notificationPermissionManager)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {
        activity = activityPluginBinding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            havePermission = resultCode == Activity.RESULT_OK
            if (havePermission) permissionsResultCallback?.success(null)
            else permissionsResultCallback?.error(
                "err_setup_tunnel",
                "Permissions are not given",
                null
            )
        }
        return havePermission
    }

    // --- Utilities ---
    private fun flutterSuccess(result: MethodChannel.Result, o: Any?) {
        scope.launch(Dispatchers.Main) { result.success(o) }
    }

    private fun flutterError(result: MethodChannel.Result, error: String) {
        scope.launch(Dispatchers.Main) { result.error(error, null, null) }
    }

    private fun flutterNotImplemented(result: MethodChannel.Result) {
        scope.launch(Dispatchers.Main) { result.notImplemented() }
    }

    // === Dart exposed methods ===
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "nativeInit" -> result.success("")
            "generateKeyPair" -> generateKeyPair(result)
            "setupTunnel" -> setupTunnel(
                call.argument<String>("tunnelName").toString(),
                result
            )

            "checkTunnelConfiguration" -> checkTunnelConfiguration(
                call.argument<String>("tunnelName").toString(), result
            )

            "connect" -> connect(call.argument<String>("cfg").toString(), result)
            "disconnect" -> disconnect(result)
            "status" -> status(result)
            "tunnelStatistics" -> statistics(result)
            "checkNotificationPermission" -> checkNotificationPermission(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            else -> flutterNotImplemented(result)
        }
    }

    private fun generateKeyPair(result: MethodChannel.Result) {
        val keyPair = KeyPair()
        result.success(
            hashMapOf(
                "privateKey" to keyPair.privateKey.toBase64(),
                "publicKey" to keyPair.publicKey.toBase64()
            )
        )
    }

    private fun setupTunnel(tunnelName: String, result: MethodChannel.Result) {
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
        status = WireguardBackend.instance.statusFlow.value
    }

    private fun checkTunnelConfiguration(tunnelName: String, result: MethodChannel.Result) {
        val intent = GoBackend.VpnService.prepare(activity)
        havePermission = intent == null
        if (havePermission) initTunnel(tunnelName)
        result.success(havePermission)
    }

    private fun startWireguardService(intent: Intent) {
        try {
            val ctx = activity ?: context
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "Starting foreground service on Android O+")
                ctx.startForegroundService(intent)
            } else {
                Log.d(TAG, "Starting service on pre-O Android")
                ctx.startService(intent)
            }
            Log.d(TAG, "Service start requested: $intent")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start WireguardWrapperService", e)
        }
    }

    private fun connect(cfg: String, result: MethodChannel.Result) {
        val tunnelName = tunnelName ?: run {
            flutterError(result, "Tunnel name is not set")
            return
        }

        status = ConnectionStatus.connecting
        Log.d(TAG, "Preparing to start WireguardWrapperService for tunnel '$tunnelName'")

        scope.launch(Dispatchers.IO) {
            try {
                if (!havePermission) {
                    checkPermission()
                    throw Exception("Permissions are not given")
                }
                WireguardBackend.instance.connectFromService(cfg, tunnelName)
                Log.d(TAG, "Tunnel '$tunnelName' successfully connected")
                flutterSuccess(result, "")
            } catch (e: WireguardConnectionException) {
                Log.e(TAG, "connectFromService failed: ${e.details}")
                flutterError(result, e.details)
            } catch (e: Exception) {
                Log.e(TAG, "connectFromService failed", e)
                flutterError(
                    result,
                    "Connection failed: ${e.message}\n${Log.getStackTraceString(e)}"
                )
            }
        }

        // Start service for foreground notification
        val intent = Intent(context, WireguardWrapperService::class.java)
        startWireguardService(intent)
    }


    private fun disconnect(result: MethodChannel.Result) {
        val tunnelName = tunnelName ?: run {
            flutterError(result, "Tunnel name is not set")
            return
        }

        status = ConnectionStatus.disconnecting
        Log.d(TAG, "Preparing to disconnect tunnel '$tunnelName'")

        scope.launch(Dispatchers.IO) {
            val backend = WireguardBackend.instance
            try {
                if (backend.runningTunnelNames.isEmpty()) {
                    throw Exception("Tunnel is not running")
                }
                backend.closeVpnTunnel(withStateChange = true)
                Log.d(TAG, "Tunnel '$tunnelName' successfully disconnected")
                flutterSuccess(result, "")
            } catch (e: Exception) {
                Log.e(TAG, "closeVpnTunnel failed", e)
                flutterError(result, e.message ?: "Disconnect failed")
            }
        }

        // **Do not start the service on disconnect** — notification will be removed by service
        Log.d(TAG, "Disconnect requested, service will update notification automatically")
    }


    private fun statistics(result: MethodChannel.Result) {
        scope.launch(Dispatchers.IO) {
            try {
                val stats = WireguardBackend.instance.getStatisticsSnapshot()
                flutterSuccess(result, Klaxon().toJsonString(stats))
            } catch (e: Throwable) {
                flutterError(result, e.message ?: "Unknown error")
            }
        }
    }

    private fun checkPermission() {
        val intent = GoBackend.VpnService.prepare(activity)
        if (intent != null) {
            havePermission = false
            activity?.startActivityForResult(intent, PERMISSIONS_REQUEST_CODE)
        } else {
            havePermission = true
        }
    }

    private fun status(result: MethodChannel.Result) {
        result.success(WireguardBackend.instance.statusFlow.value.name)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        val callback = object : NotificationPermissionCallback {
            override fun onResult(permissionStatus: NotificationPermission) {
                result.success(permissionStatus.name)
            }

            override fun onError(exception: Exception) {
                flutterError(result, exception.message.toString())
            }
        }
        notificationPermissionManager.requestPermission(checkActivity(), callback)
    }

    private fun checkNotificationPermission(result: MethodChannel.Result) {
        val status = notificationPermissionManager.checkPermission(checkActivity())
        result.success(status.name)
    }

    private fun checkActivity(): Activity {
        return activity ?: throw ActivityNotAttachedException()
    }
}
