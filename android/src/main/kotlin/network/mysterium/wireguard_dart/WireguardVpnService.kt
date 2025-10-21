package network.mysterium.wireguard_dart

import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.wireguard.android.backend.GoBackend
import kotlinx.coroutines.*
import java.sql.Connection

class WireguardWrapperService : GoBackend.VpnService() {

    private val serviceTag = "WireguardWrapperService"
    private val scope = CoroutineScope(Job() + Dispatchers.Main)
    private lateinit var notificationHelper: NotificationHelper
    private var updateJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        notificationHelper = NotificationHelper(this)
        NotificationHelper.initNotificationChannel(this)
        WireguardBackend.instance.serviceCreated(this)
        Log.d(serviceTag, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val backend = WireguardBackend.instance

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

        updateJob?.cancel()
        var startedTunnel = false

        updateJob = scope.launch {
            while (isActive) {
                val status = backend.statusFlow.value
                val stats = backend.latestStats

                if (status == ConnectionStatus.connected) {
                    startedTunnel = true
                }

                if (startedTunnel && status == ConnectionStatus.disconnected) {
                    Log.d(serviceTag, "Tunnel disconnected, stopping service")
                    stopForeground(true)
                    stopSelf()
                    break
                } else if (status != ConnectionStatus.disconnected) {
                    notificationHelper.updateStatusNotification(
                        status,
                        stats,
                        backend.tunnelName ?: "Mysterium VPN"
                    )
                }

                delay(1000)
            }
        }

        return START_STICKY

    }

    override fun onDestroy() {
        updateJob?.cancel()
        WireguardBackend.instance.serviceDestroyed()
        super.onDestroy()
        Log.d(serviceTag, "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
