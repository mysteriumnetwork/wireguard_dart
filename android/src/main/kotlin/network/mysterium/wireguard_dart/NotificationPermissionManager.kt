package network.mysterium.wireguard_dart

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry

const val REQUEST_NOTIFICATION_PERMISSION = 100
const val NOTIFICATION_PERMISSION_STATUS_PREFS =
    "network.mysterium.wireguard_dart.prefs.NOTIFICATION_PERMISSION_STATUS"
private const val POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"

class NotificationPermissionManager : PluginRegistry.RequestPermissionsResultListener {
    private var activity: Activity? = null
    private var callback: NotificationPermissionCallback? = null

    fun checkPermission(activity: Activity): NotificationPermission {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return NotificationPermission.GRANTED
        }

        val permission = POST_NOTIFICATIONS_PERMISSION
        if (activity.isPermissionGranted(permission)) {
            return NotificationPermission.GRANTED
        }

        val prevPermissionStatus = activity.getPrevPermissionStatus(permission)
        return when {
            prevPermissionStatus == NotificationPermission.PERMANENTLY_DENIED &&
                    !activity.shouldShowRequestPermissionRationale(permission) ->
                NotificationPermission.PERMANENTLY_DENIED

            else -> NotificationPermission.DENIED
        }
    }

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

        ActivityCompat.requestPermissions(
            activity,
            arrayOf(permission),
            REQUEST_NOTIFICATION_PERMISSION
        )
    }

    private fun Context.isPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun Context.setPrevPermissionStatus(
        permission: String,
        status: NotificationPermission
    ) {
        val prefs = getSharedPreferences(
            NOTIFICATION_PERMISSION_STATUS_PREFS, Context.MODE_PRIVATE
        )
        prefs.edit().putString(permission, status.toString()).apply()
    }

    private fun Context.getPrevPermissionStatus(permission: String): NotificationPermission? {
        val prefs = getSharedPreferences(
            NOTIFICATION_PERMISSION_STATUS_PREFS, Context.MODE_PRIVATE
        )
        val value = prefs.getString(permission, null) ?: return null
        return NotificationPermission.valueOf(value)
    }

    private fun disposeReference() {
        this.activity = null
        this.callback = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback?.onResult(NotificationPermission.GRANTED)
            return true
        }

        if (grantResults.isEmpty()) {
            callback?.onError(PermissionRequestCancelledException())
            disposeReference()
            return false
        }

        val permission = POST_NOTIFICATIONS_PERMISSION
        val permissionIndex = permissions.indexOf(permission)
        var permissionStatus = NotificationPermission.DENIED

        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            if (permissionIndex >= 0 &&
                grantResults[permissionIndex] == PackageManager.PERMISSION_GRANTED
            ) {
                permissionStatus = NotificationPermission.GRANTED
            } else if (activity?.shouldShowRequestPermissionRationale(permission) == false) {
                permissionStatus = NotificationPermission.PERMANENTLY_DENIED
            }
        } else return false

        activity?.setPrevPermissionStatus(permission, permissionStatus)
        callback?.onResult(permissionStatus)
        disposeReference()
        return true
    }
}
