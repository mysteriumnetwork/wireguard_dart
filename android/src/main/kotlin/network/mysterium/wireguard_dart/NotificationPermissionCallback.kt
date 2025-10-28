package network.mysterium.wireguard_dart

interface NotificationPermissionCallback {
    fun onResult(permissionStatus: NotificationPermission)
    fun onError(exception: Exception)
}