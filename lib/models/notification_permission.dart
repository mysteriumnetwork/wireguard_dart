/// Represents the result of a notification permission request.
enum NotificationPermission {
  /// Notification permission has been granted.
  granted,

  /// Notification permission has been denied.
  denied,

  /// Notification permission has been permanently denied.
  permanentlyDenied;

  static NotificationPermission fromIndex(int? index) {
    final int safeIndex = index ?? NotificationPermission.denied.index;
    if (safeIndex < 0 || safeIndex >= NotificationPermission.values.length) {
      return NotificationPermission.denied;
    }
    return NotificationPermission.values[safeIndex];
  }
}
