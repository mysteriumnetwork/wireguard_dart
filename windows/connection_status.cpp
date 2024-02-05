#include "connection_status.h"

#include <windows.h>

#include <string>

namespace wireguard_dart {

std::string ConnectionStatusToString(const ConnectionStatus status) {
  switch (status) {
    case ConnectionStatus::connected:
      return "connected";
    case ConnectionStatus::disconnected:
      return "disconnected";
    case ConnectionStatus::connecting:
      return "connecting";
    case ConnectionStatus::disconnecting:
      return "disconnecting";
    default:
      return "unknown";
  }
}

ConnectionStatus ConnectionStatusFromWinSvcState(DWORD dwCurrentState) {
  switch (dwCurrentState) {
    case SERVICE_RUNNING:
      return ConnectionStatus::connected;
    case SERVICE_STOPPED:
    case SERVICE_PAUSED:
      return ConnectionStatus::disconnected;
    case SERVICE_START_PENDING:
    case SERVICE_CONTINUE_PENDING:
      return ConnectionStatus::connecting;
    case SERVICE_STOP_PENDING:
    case SERVICE_PAUSE_PENDING:
      return ConnectionStatus::disconnecting;
    default:
      return ConnectionStatus::unknown;
  }
}

}  // namespace wireguard_dart
