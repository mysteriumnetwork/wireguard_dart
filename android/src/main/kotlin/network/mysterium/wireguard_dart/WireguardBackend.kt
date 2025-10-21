package network.mysterium.wireguard_dart

import android.content.Context
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

    private val executor = Executors.newSingleThreadExecutor { r -> Thread(r, "wireguard-io-thread") }
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
        Log.d(serviceTag, "Status updated: $status")
        _statusFlow.value = status
    }

    suspend fun connectFromService(cfgString: String, tunnelName: String) {
        Log.d(serviceTag, "connectFromService: Initializing tunnel '$tunnelName'")

        withContext(wireGuardDispatcher) {
            try {
                val cfg = Config.parse(ByteArrayInputStream(cfgString.toByteArray()))
                currentConfig = cfg
                Log.d(serviceTag, "Config parsed successfully for tunnel '$tunnelName'")

                currentTunnel = WireguardTunnel(tunnelName) { state ->
                    val newStatus = when (state) {
                        Tunnel.State.UP -> ConnectionStatus.connected
                        Tunnel.State.DOWN -> ConnectionStatus.disconnected
                        else -> ConnectionStatus.unknown
                    }
                    Log.d(serviceTag, "Tunnel '$tunnelName' state changed: $state -> $newStatus")
                    updateStatus(newStatus)
                }

                backend.setState(currentTunnel!!, Tunnel.State.UP, cfg)

                startMonitoringJob()
                Log.d(serviceTag, "Tunnel '$tunnelName' setState completed")
            } catch (e: Exception) {
                val detailedMessage = StringBuilder()
                    .append("Exception type: ${e::class.simpleName}\n")
                    .append("Message: ${e.message}\n")
                    .append("StackTrace:\n${Log.getStackTraceString(e)}")
                    .toString()

                Log.e(serviceTag, "connectFromService failed for tunnel '$tunnelName': $detailedMessage")
                updateStatus(ConnectionStatus.disconnected)
                _latestStats = null

                throw WireguardConnectionException(
                    tunnelName = tunnelName,
                    originalException = e,
                    details = detailedMessage
                )
            }
        }
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
                val state = try {
                    backend.getState(tunnel)
                } catch (e: Exception) {
                    Log.e(serviceTag, "Failed to read tunnel state", e)
                    Tunnel.State.DOWN
                }

                val newStatus = when (state) {
                    Tunnel.State.UP -> ConnectionStatus.connected
                    Tunnel.State.DOWN -> ConnectionStatus.disconnected
                    else -> ConnectionStatus.unknown
                }

                updateStatus(newStatus)

                // Update latest statistics or null if disconnected
                _latestStats = if (newStatus == ConnectionStatus.connected) {
                    getStatisticsSnapshot()
                } else null

                delay(1000)
            }
        }
    }

    suspend fun closeVpnTunnel(withStateChange: Boolean) {
        monitoringJob?.cancel()
        if (withStateChange) updateStatus(ConnectionStatus.disconnected)
        _latestStats = null

        withContext(wireGuardDispatcher) {
            currentTunnel?.let {
                backend.setState(it, Tunnel.State.DOWN, null)
            }
        }
    }

    suspend fun getStatisticsSnapshot(): TunnelStatistics? {
        val tunnel = currentTunnel ?: return null

        return withContext(wireGuardDispatcher) {
            val stats = backend.getStatistics(tunnel)
            var latestHandshake = 0L
            for (peer in stats.peers()) {
                stats.peer(peer)?.let {
                    if (it.latestHandshakeEpochMillis > latestHandshake) {
                        latestHandshake = it.latestHandshakeEpochMillis
                    }
                }
            }
            TunnelStatistics(stats.totalRx(), stats.totalTx(), latestHandshake)
        }
    }
}
