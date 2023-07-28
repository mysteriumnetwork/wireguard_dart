enum ConnectionStatus {
  connecting,
  connected,
  disconnecting,
  disconnected,
  unknown;

  factory ConnectionStatus.fromString(String s) {
    return ConnectionStatus.values
        .firstWhere((v) => v.name == s, orElse: () => ConnectionStatus.unknown);
  }
}
