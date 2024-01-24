#include "connection_status.h"
#include <string>

namespace wireguard_dart {

std::string ConnectionStatusToString(const ConnectionStatus status) {
    switch(status) {
        case ConnectionStatus::connected: return "connected";
        case ConnectionStatus::disconnected: return "disconnected";
        case ConnectionStatus::connecting: return "connecting";
        case ConnectionStatus::disconnecting: return "disconnecting";
        default: return "unknown";
    }
}

}  // namespace wireguard_dart
