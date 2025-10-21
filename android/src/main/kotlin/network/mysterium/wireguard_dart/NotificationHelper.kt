package network.mysterium.wireguard_dart

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Locale

class NotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "network_wireguard_channel"
        const val NOTIFICATION_ID = 424242

        fun initNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "VPN Status",
                    NotificationManager.IMPORTANCE_LOW
                )
                channel.description = "VPN connection"
                val mgr = context.getSystemService(NotificationManager::class.java)
                mgr?.createNotificationChannel(channel)
            }
        }
    }

    fun buildTunnelNotification(
        status: ConnectionStatus,
        stats: TunnelStatistics?,
        notificationTitle: String,
    ): Notification {

        val baseText = when (status) {
            ConnectionStatus.connected -> "Connected"
            ConnectionStatus.connecting -> "Connecting..."
            ConnectionStatus.disconnecting -> "Disconnecting..."
            ConnectionStatus.disconnected -> "Disconnected"
            else -> "Unknown"
        }

        val text = if (stats != null) {
            val upload = formatBytes(stats.totalUpload)
            val download = formatBytes(stats.totalDownload)
            "$baseText • ↑ $upload • ↓ $download"
        } else baseText

        val pending = android.app.PendingIntent.getActivity(
            context,
            0,
            Intent(context, getLaunchActivityClass(context)),
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(notificationTitle)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_notification_overlay)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    fun updateStatusNotification(
        status: ConnectionStatus,
        stats: TunnelStatistics? = null,
        notificationTitle: String,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, buildTunnelNotification(status, stats, notificationTitle))
    }

    private fun formatBytes(bytes: Long): String {
        val kb = 1024
        val mb = kb * 1024
        val gb = mb * 1024
        return when {
            bytes >= gb -> String.format(Locale.US, "%.2f GB", bytes.toDouble() / gb)
            bytes >= mb -> String.format(Locale.US, "%.2f MB", bytes.toDouble() / mb)
            bytes >= kb -> String.format(Locale.US, "%.2f KB", bytes.toDouble() / kb)
            else -> "$bytes B"
        }
    }


    @SuppressLint("DiscouragedPrivateApi")
    private fun getLaunchActivityClass(context: Context): Class<*> {
        val pm = context.packageManager
        val intent = pm.getLaunchIntentForPackage(context.packageName)
        val className = intent?.component?.className
        return try {
            val classNameNonNull =
                className ?: throw IllegalStateException("Launch activity className is null")
            Class.forName(classNameNonNull)
        } catch (_: Exception) {
            android.app.Activity::class.java
        }
    }
}
