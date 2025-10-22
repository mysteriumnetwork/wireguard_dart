package network.mysterium.wireguard_dart

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import io.flutter.plugin.common.PluginRegistry

private const val REQUEST_NOTIFICATION_PERMISSION = 100
private const val REQUEST_NOTIFICATION_SETTINGS = 101
private const val NOTIFICATION_PERMISSION_STATUS_PREFS =
    "network.mysterium.wireguard_dart.prefs.NOTIFICATION_PERMISSION_STATUS"
private const val POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"

class NotificationPermissionManager : PluginRegistry.RequestPermissionsResultListener {

    private var activity: Activity? = null
    private var callback: NotificationPermissionCallback? = null

    // --- Check current permission ---
    fun checkPermission(activity: Activity): NotificationPermission {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return NotificationPermission.GRANTED

        val permission = POST_NOTIFICATIONS_PERMISSION
        val isGranted = activity.isPermissionGranted(permission)

        val status = when {
            isGranted -> NotificationPermission.GRANTED
            !activity.shouldShowRequestPermissionRationale(permission) -> NotificationPermission.PERMANENTLY_DENIED
            else -> NotificationPermission.DENIED
        }

        activity.setPrevPermissionStatus(permission, status)
        return status
    }

    // --- Request permission via system dialog ---
    fun requestPermission(activity: Activity, callback: NotificationPermissionCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback.onResult(NotificationPermission.GRANTED)
            return
        }

        val permission = POST_NOTIFICATIONS_PERMISSION
        if (activity.isPermissionGranted(permission)) {
            callback.onResult(NotificationPermission.GRANTED)
            return
        }

        this.activity = activity
        this.callback = callback

        ActivityCompat.requestPermissions(activity, arrayOf(permission), REQUEST_NOTIFICATION_PERMISSION)
    }

    // --- Open notification settings page ---
    fun openAppNotificationSettings(activity: Activity, callback: NotificationPermissionCallback) {
        this.activity = activity
        this.callback = callback

        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = "package:${activity.packageName}".toUri()
            }
        }

        activity.startActivityForResult(intent, REQUEST_NOTIFICATION_SETTINGS)
    }

    // --- Override stored permission (does not affect system permission) ---
    fun overrideStoredPermissionStatus(context: Context, status: NotificationPermission) {
        context.setPrevPermissionStatus(POST_NOTIFICATIONS_PERMISSION, status)
    }

    // --- Handle activity results for both permission request & settings ---
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_NOTIFICATION_PERMISSION, REQUEST_NOTIFICATION_SETTINGS -> {
                val status = activity?.let { checkPermission(it) } ?: NotificationPermission.DENIED
                callback?.onResult(status)
                disposeReference()
                return true
            }
        }
        return false
    }

    // --- Helpers ---
    private fun Context.isPermissionGranted(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun Context.setPrevPermissionStatus(permission: String, status: NotificationPermission) {
        val prefs = getSharedPreferences(NOTIFICATION_PERMISSION_STATUS_PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(permission, status.toString()).apply()
    }

    private fun Context.getPrevPermissionStatus(permission: String): NotificationPermission? {
        val prefs = getSharedPreferences(NOTIFICATION_PERMISSION_STATUS_PREFS, Context.MODE_PRIVATE)
        return prefs.getString(permission, null)?.let { NotificationPermission.valueOf(it) }
    }

    private fun disposeReference() {
        this.activity = null
        this.callback = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback?.onResult(NotificationPermission.GRANTED)
            return true
        }

        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return false
        if (grantResults.isEmpty()) {
            callback?.onError(PermissionRequestCancelledException())
            disposeReference()
            return false
        }

        val permissionIndex = permissions.indexOf(POST_NOTIFICATIONS_PERMISSION)
        val status = if (permissionIndex >= 0 && grantResults[permissionIndex] == PackageManager.PERMISSION_GRANTED) {
            NotificationPermission.GRANTED
        } else if (activity?.shouldShowRequestPermissionRationale(POST_NOTIFICATIONS_PERMISSION) == false) {
            NotificationPermission.PERMANENTLY_DENIED
        } else {
            NotificationPermission.DENIED
        }

        activity?.setPrevPermissionStatus(POST_NOTIFICATIONS_PERMISSION, status)
        callback?.onResult(status)
        disposeReference()
        return true
    }
}
