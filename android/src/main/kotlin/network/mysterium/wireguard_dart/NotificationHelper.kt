package network.mysterium.wireguard_dart

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

class NotificationHelper(private val context: Context) {

    private val logTag = "NotificationHelper"

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

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }

        val pending = launchIntent?.let {
            android.app.PendingIntent.getActivity(
                context,
                0,
                it,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(notificationTitle)
            .setContentText(text)
            .setSmallIcon(R.drawable.baseline_vpn_key_24)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        if (pending != null) {
            builder.setContentIntent(pending)
        }

        return builder.build()
    }

    fun updateStatusNotification(
        status: ConnectionStatus,
        stats: TunnelStatistics? = null,
        notificationTitle: String,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager = context.getSystemService(NotificationManager::class.java)
        try {
            manager?.notify(NOTIFICATION_ID, buildTunnelNotification(status, stats, notificationTitle))
        } catch (e: SecurityException) {
            Log.w(logTag, "Unable to update notification due to security restriction", e)
        }
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
}
