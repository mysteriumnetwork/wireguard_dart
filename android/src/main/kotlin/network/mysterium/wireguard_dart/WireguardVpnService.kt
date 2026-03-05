package network.mysterium.wireguard_dart

import android.content.Intent
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import com.wireguard.android.backend.GoBackend
import kotlinx.coroutines.*

class WireguardWrapperService : GoBackend.VpnService() {

    companion object {
        private const val NOTIFICATION_UPDATE_MIN_INTERVAL_MS = 2_000L
    }

    private val serviceTag = "WireguardWrapperService"
    private val scope = CoroutineScope(Job() + Dispatchers.Main)
    private lateinit var notificationHelper: NotificationHelper
    private var updateJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        notificationHelper = NotificationHelper(this)
        NotificationHelper.initNotificationChannel(this)
        val backend = WireguardBackend.getOrCreateInstance(this)
        backend.serviceCreated(this)
        Log.d(serviceTag, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val backend = WireguardBackend.getOrCreateInstance(this)

        // Show foreground notification immediately
        startForeground(
            NotificationHelper.NOTIFICATION_ID,
            notificationHelper.buildTunnelNotification(
                ConnectionStatus.connecting,
                TunnelStatistics(0, 0, 0),
                "VPN"
            )
        )

        // Cancel previous job if any
        updateJob?.cancel()
        var startedTunnel = false
        var lastNotifiedStatus: ConnectionStatus? = null
        var lastNotifiedStats: TunnelStatistics? = null
        var lastNotifiedTitle: String? = null
        var lastNotifiedAtMs = 0L

        updateJob = scope.launch {
            while (isActive) {
                val status = backend.statusFlow.value
                val stats = backend.latestStats
            val notificationTitle = backend.tunnelName ?: "Mysterium VPN"

                if (status == ConnectionStatus.connected) {
                    startedTunnel = true
                }

                if (startedTunnel && status == ConnectionStatus.disconnected) {
                    Log.d(serviceTag, "Tunnel disconnected, stopping service")
                    stopForeground(true)
                    stopSelf()
                    break
                } else if (status != ConnectionStatus.disconnected) {
                    val statusOrTitleChanged =
                        status != lastNotifiedStatus || notificationTitle != lastNotifiedTitle
                    val statsChanged = stats != lastNotifiedStats
                    val nowMs = SystemClock.elapsedRealtime()
                    val intervalElapsed =
                        nowMs - lastNotifiedAtMs >= NOTIFICATION_UPDATE_MIN_INTERVAL_MS
                    val shouldUpdateNotification =
                        statusOrTitleChanged || (statsChanged && intervalElapsed)

                    if (shouldUpdateNotification) {
                        notificationHelper.updateStatusNotification(
                            status,
                            stats,
                            notificationTitle
                        )
                        lastNotifiedStatus = status
                        lastNotifiedStats = stats
                        lastNotifiedTitle = notificationTitle
                        lastNotifiedAtMs = nowMs
                    }
                }

                delay(1000)
            }
        }

        return START_STICKY

    }

    override fun onDestroy() {
        updateJob?.cancel()
        WireguardBackend.getOrCreateInstance(this).serviceDestroyed()
        super.onDestroy()
        Log.d(serviceTag, "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
