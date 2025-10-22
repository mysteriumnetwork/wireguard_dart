package network.mysterium.wireguard_dart

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.ByteArrayInputStream
import java.util.concurrent.Executors

class WireguardBackend private constructor(
    private val appContext: Context,
    private val mainScope: CoroutineScope
) {
    private val serviceTag = "WireguardBackend"

    private val executor =
        Executors.newSingleThreadExecutor { r -> Thread(r, "wireguard-io-thread") }
    private val wireGuardDispatcher = executor.asCoroutineDispatcher()

    private val backend: GoBackend by lazy { GoBackend(appContext) }

    private var currentTunnel: WireguardTunnel? = null
    private var currentConfig: Config? = null
    private var monitoringJob: Job? = null
    private var serviceRef: WireguardWrapperService? = null

    private val _statusFlow = MutableStateFlow(ConnectionStatus.disconnected)
    val statusFlow: StateFlow<ConnectionStatus> = _statusFlow

    private var _latestStats: TunnelStatistics? = null
    val latestStats: TunnelStatistics? get() = _latestStats

    val tunnelName: String?
        get() = currentTunnel?.getName()

    val runningTunnelNames: Set<String>
        get() = backend.runningTunnelNames

    companion object {
        @Volatile
        lateinit var instance: WireguardBackend
            private set

        fun init(context: Context, mainScope: CoroutineScope) {
            if (!::instance.isInitialized) {
                instance = WireguardBackend(context.applicationContext, mainScope)
                Log.d("WireguardBackend", "Backend singleton initialized")
            }
        }
    }

    fun serviceCreated(service: WireguardWrapperService) {
        serviceRef = service
        Log.d(serviceTag, "Service reference set in backend")
    }

    fun serviceDestroyed() {
        serviceRef = null
        Log.d(serviceTag, "Service reference cleared")
    }

    fun updateStatus(status: ConnectionStatus) {
        _statusFlow.value = status
    }

    suspend fun connectFromService(cfgString: String, tunnelName: String, context: Context) {
        Log.d(serviceTag, "connectFromService: Initializing tunnel '$tunnelName'")
        withContext(wireGuardDispatcher) {
            try {
                val cfg = Config.parse(ByteArrayInputStream(cfgString.toByteArray()))
                currentConfig = cfg

                // Initialize tunnel if needed
                if (currentTunnel?.getName() != tunnelName) {
                    currentTunnel = WireguardTunnel(tunnelName) { state ->
                        val newStatus = when (state) {
                            Tunnel.State.UP -> ConnectionStatus.connected
                            Tunnel.State.DOWN -> ConnectionStatus.disconnected
                            else -> ConnectionStatus.unknown
                        }
                        if (newStatus == ConnectionStatus.connected) {
                            startServiceIfNeeded(context)
                        }
                        Log.d(
                            serviceTag,
                            "Tunnel '$tunnelName' state changed: $state -> $newStatus"
                        )
                        updateStatus(newStatus)
                    }
                }

                backend.setState(currentTunnel!!, Tunnel.State.UP, cfg)

                startMonitoringJob()
                Log.d(serviceTag, "Tunnel '$tunnelName' setState completed")
            } catch (e: Exception) {
                val detailedMessage =
                    "Exception: ${e::class.simpleName}\nMessage: ${e.message}\nStack:\n${
                        Log.getStackTraceString(e)
                    }"
                Log.e(serviceTag, "connectFromService failed: $detailedMessage")
                updateStatus(ConnectionStatus.disconnected)
                _latestStats = null
                throw WireguardConnectionException(tunnelName, e, detailedMessage)
            }
        }
    }

    fun stopService(context: Context) {
        serviceRef?.let {
            try {
                val intent = Intent(context, WireguardWrapperService::class.java)
                context.stopService(intent)
                Log.d(serviceTag, "WireguardWrapperService stopped")
            } catch (e: Exception) {
                Log.e(serviceTag, "Failed to stop WireguardWrapperService", e)
            }
            serviceRef = null
        } ?: Log.d(serviceTag, "No service reference to stop")
    }

    private fun startMonitoringJob() {
        monitoringJob?.cancel()
        val tunnel = currentTunnel ?: run {
            Log.w(serviceTag, "startMonitoringJob: No tunnel initialized")
            return
        }

        monitoringJob = mainScope.launch(wireGuardDispatcher) {
            Log.d(serviceTag, "Monitoring job started for tunnel '${tunnel.getName()}'")
            while (isActive) {

                // Check if tunnel was removed externally
                if (!backend.runningTunnelNames.contains(tunnel.getName())) {
                    Log.w(serviceTag, "Tunnel '${tunnel.getName()}' removed externally")
                    _latestStats = null
                    updateStatus(ConnectionStatus.disconnected)
                    break // Stop monitoring but do NOT stop service
                }

                // Update latest stats only if connected
                _latestStats =
                    if (_statusFlow.value == ConnectionStatus.connected) getStatisticsSnapshot() else null

                delay(1000) // <-- 1 seconds delay
            }
        }
    }

    fun startServiceIfNeeded(context: Context) {
        val intent = Intent(context, WireguardWrapperService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(serviceTag, "WireguardWrapperService started")
        } catch (e: Exception) {
            Log.e(serviceTag, "Failed to start WireguardWrapperService", e)
        }
    }

    suspend fun closeVpnTunnel(withStateChange: Boolean, context: Context) {
        val tunnel = currentTunnel ?: run {
            throw Exception("Tunnel is not initialized")
        }
        if (runningTunnelNames.isEmpty()) {
            throw Exception("Tunnel is not running")
        }
        updateStatus(ConnectionStatus.disconnecting)
        monitoringJob?.cancel()
        monitoringJob = null
        _latestStats = null
        stopService(context)

        withContext(wireGuardDispatcher) {
            tunnel.let {
                backend.setState(it, Tunnel.State.DOWN, null)
            }
        }
        updateStatus(ConnectionStatus.disconnected)
    }

    suspend fun getStatisticsSnapshot(): TunnelStatistics? {
        val tunnel = currentTunnel ?: return null
        return withContext(wireGuardDispatcher) {
            val stats = backend.getStatistics(tunnel)
            val latestHandshake =
                stats.peers().mapNotNull { stats.peer(it)?.latestHandshakeEpochMillis }.maxOrNull()
                    ?: 0L
            TunnelStatistics(stats.totalRx(), stats.totalTx(), latestHandshake)
        }
    }
}
