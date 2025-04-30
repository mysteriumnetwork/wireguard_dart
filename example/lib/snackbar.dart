import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

enum MessageType {
  success,
  error,
  info,
}

void showSnackbar(
  String message, {
  SnackBarAction? action,
  MessageType type = MessageType.error,
  TextAlign textAlign = TextAlign.center,
}) {
  final snackBar = SnackBar(
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    behavior: SnackBarBehavior.floating,
    backgroundColor: switch (type) {
      MessageType.error => Colors.red,
      MessageType.info => Colors.blue,
      MessageType.success => Colors.green,
    },
    content: Center(
      child: Text(
        message,
        maxLines: 3,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        textAlign: textAlign,
      ),
    ),
    action: action,
  );

  snackbarKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(snackBar);
}
