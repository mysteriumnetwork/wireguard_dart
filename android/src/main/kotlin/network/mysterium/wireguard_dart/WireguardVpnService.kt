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
        private const val DEFAULT_NOTIFICATION_TITLE = "Mysterium VPN"
    }

    private val serviceTag = "WireguardWrapperService"
    private val scope = CoroutineScope(Job() + Dispatchers.Main)
    private lateinit var notificationHelper: NotificationHelper
    private var updateJob: Job? = null
    private var startedInForeground = false

    override fun onCreate() {
        super.onCreate()
        notificationHelper = NotificationHelper(this)
        NotificationHelper.initNotificationChannel(this)
        val backend = WireguardBackend.getOrCreateInstance(this)

        // Satisfy the startForegroundService() contract as early as possible. Android arms a
        // ~10s deadline at startForegroundService() and crashes the process with
        // ForegroundServiceDidNotStartInTimeException if startForeground() is not called in time.
        // Doing it here (instead of only in onStartCommand) guarantees we beat the deadline even
        // when the main thread is busy or onStartCommand is delayed.
        startedInForeground = notificationHelper.startForegroundSafely(
            this,
            NotificationHelper.NOTIFICATION_ID,
            notificationHelper.buildTunnelNotification(
                ConnectionStatus.connecting,
                TunnelStatistics(0, 0, 0),
                backend.tunnelName ?: DEFAULT_NOTIFICATION_TITLE
            )
        )

        if (!startedInForeground) {
            // The startForegroundService() contract can no longer be met. Stop now: a destroying
            // service makes the system's foreground-timeout handler bail out, so we avoid the
            // ForegroundServiceDidNotStartInTimeException instead of lingering with an unmet contract.
            Log.w(serviceTag, "Unable to enter foreground in onCreate, stopping service")
            stopSelf()
            return
        }

        backend.serviceCreated(this)
        Log.d(serviceTag, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val backend = WireguardBackend.getOrCreateInstance(this)

        // The foreground notification is normally posted in onCreate to beat the
        // startForegroundService() deadline. Re-assert it here (idempotent) so a re-delivered
        // start that reuses an existing instance keeps the service in the foreground.
        if (notificationHelper.startForegroundSafely(
                this,
                NotificationHelper.NOTIFICATION_ID,
                notificationHelper.buildTunnelNotification(
                    ConnectionStatus.connecting,
                    TunnelStatistics(0, 0, 0),
                    backend.tunnelName ?: DEFAULT_NOTIFICATION_TITLE
                )
            )
        ) {
            startedInForeground = true
        }

        if (!startedInForeground) {
            // Foreground was never successfully established (onCreate's attempt failed and this one
            // did too), so the startForegroundService() contract is unmet. Stop rather than risk
            // ForegroundServiceDidNotStartInTimeException. A failed re-assert while already in the
            // foreground is harmless and intentionally does not stop a working tunnel.
            Log.w(serviceTag, "Unable to enter foreground in onStartCommand, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        // Cancel previous job if any
        updateJob?.cancel()
        var startedTunnel = false
        var lastNotifiedStatus: ConnectionStatus? = null
        var lastNotifiedStats: TunnelStatistics? = null
        var lastNotifiedTitle: String? = null
        var lastNotificationAttemptAtMs = 0L

        updateJob = scope.launch {
            while (isActive) {
                val status = backend.statusFlow.value
                val stats = backend.latestStats
                val notificationTitle = backend.tunnelName ?: DEFAULT_NOTIFICATION_TITLE

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
                        nowMs - lastNotificationAttemptAtMs >= NOTIFICATION_UPDATE_MIN_INTERVAL_MS
                    val shouldUpdateNotification =
                        statusOrTitleChanged || (statsChanged && intervalElapsed)

                    if (shouldUpdateNotification) {
                        lastNotificationAttemptAtMs = nowMs
                        val notificationPosted = notificationHelper.updateStatusNotification(
                            status,
                            stats,
                            notificationTitle
                        )
                        if (notificationPosted) {
                            lastNotifiedStatus = status
                            lastNotifiedStats = stats
                            lastNotifiedTitle = notificationTitle
                        }
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
