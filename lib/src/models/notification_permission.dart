/// Represents the result of a notification permission request.
enum NotificationPermission {
  /// Notification permission has been granted.
  granted,

  /// Notification permission has been denied.
  denied,

  /// Notification permission has been permanently denied.
  permanentlyDenied;

  /// Converts a string (from Android native side) into a [NotificationPermission].
  static NotificationPermission fromString(String? value) => switch (value?.toUpperCase()) {
        'GRANTED' => NotificationPermission.granted,
        'PERMANENTLY_DENIED' => NotificationPermission.permanentlyDenied,
        'DENIED' || null => NotificationPermission.denied,
        _ => NotificationPermission.denied,
      };
}
