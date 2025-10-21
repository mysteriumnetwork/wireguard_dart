package network.mysterium.wireguard_dart

import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.wireguard.android.backend.GoBackend
import kotlinx.coroutines.*

class WireguardWrapperService : GoBackend.VpnService() {

    private val serviceTag = "WireguardWrapperService"
    private val scope = CoroutineScope(Job() + Dispatchers.Main)
    private lateinit var notificationHelper: NotificationHelper
    private var updateJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        notificationHelper = NotificationHelper(this)
        WireguardBackend.instance.serviceCreated(this)
        Log.d(serviceTag, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val backend = WireguardBackend.instance
        val notificationTitle = backend.tunnelName ?: "VPN"

        // Always show foreground notification immediately
        startForeground(
            NotificationHelper.NOTIFICATION_ID,
            notificationHelper.buildTunnelNotification(
                backend.statusFlow.value,
                backend.latestStats ?: TunnelStatistics(0,0,0),
                notificationTitle
            )
        )

        // Update notification continuously
        updateJob?.cancel()
        updateJob = scope.launch {
            while (isActive) {
                val status = backend.statusFlow.value
                val stats = backend.latestStats
                if (status == ConnectionStatus.disconnected) stopForeground(STOP_FOREGROUND_REMOVE)
                else notificationHelper.updateStatusNotification(status, stats, notificationTitle)
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
