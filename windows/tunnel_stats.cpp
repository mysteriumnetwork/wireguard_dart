#include "tunnel_stats.h"

#include <windows.h>

#include <sstream>
#include <vector>

#include "wireguard.h"

// Defined in wireguard_dart_plugin.cpp, declared here the same way it is there.
std::string GetLastErrorAsString(DWORD error_code);

namespace wireguard_dart {

namespace {
// 100ns intervals between 1601-01-01 and 1970-01-01. The driver timestamps a
// handshake as a FILETIME; UAPI counts from the Unix epoch.
constexpr DWORD64 kUnixEpochIn100ns = 116444736000000000ULL;
constexpr DWORD64 k100nsPerSecond = 10000000ULL;
// Enough for a single-peer tunnel, which is every tunnel this plugin builds.
// The driver reports what it needs when it is not, and the read is retried.
constexpr DWORD kInitialConfigBytes = 1024;
constexpr int kConfigReadAttempts = 4;

struct DriverApi {
  WIREGUARD_OPEN_ADAPTER_FUNC *open_adapter;
  WIREGUARD_CLOSE_ADAPTER_FUNC *close_adapter;
  WIREGUARD_GET_CONFIGURATION_FUNC *get_configuration;
};

// Resolved once. The DLL ships beside the executable and stays loaded for the
// lifetime of the process, so a poll running every second must not pay for a
// load and three lookups each time.
const DriverApi *Driver() {
  static const DriverApi *const api = []() -> const DriverApi * {
    const HMODULE library = LoadLibraryExW(L"wireguard.dll", nullptr,
                                           LOAD_LIBRARY_SEARCH_APPLICATION_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (library == nullptr) {
      return nullptr;
    }
    static DriverApi resolved{};
    resolved.open_adapter = reinterpret_cast<WIREGUARD_OPEN_ADAPTER_FUNC *>(
        reinterpret_cast<void *>(GetProcAddress(library, "WireGuardOpenAdapter")));
    resolved.close_adapter = reinterpret_cast<WIREGUARD_CLOSE_ADAPTER_FUNC *>(
        reinterpret_cast<void *>(GetProcAddress(library, "WireGuardCloseAdapter")));
    resolved.get_configuration = reinterpret_cast<WIREGUARD_GET_CONFIGURATION_FUNC *>(
        reinterpret_cast<void *>(GetProcAddress(library, "WireGuardGetConfiguration")));
    if (resolved.open_adapter == nullptr || resolved.close_adapter == nullptr ||
        resolved.get_configuration == nullptr) {
      FreeLibrary(library);
      return nullptr;
    }
    return &resolved;
  }();
  return api;
}

TunnelStatsResult Failure(const std::string &what, DWORD error_code) {
  std::string message = what;
  if (error_code != 0) {
    message += " Windows Error Code: " + std::to_string(error_code) + ".";
    message += " Description: " + GetLastErrorAsString(error_code);
  }
  return {TunnelStatsStatus::kFailed, "", message};
}

// Walks the peers the driver packed after the interface struct, each one
// followed by its own variable-length run of allowed IPs.
std::string ToUapi(const WIREGUARD_INTERFACE *config) {
  std::ostringstream uapi;
  const BYTE *cursor = reinterpret_cast<const BYTE *>(config) + sizeof(WIREGUARD_INTERFACE);

  for (DWORD peer_index = 0; peer_index < config->PeersCount; peer_index++) {
    const WIREGUARD_PEER *peer = reinterpret_cast<const WIREGUARD_PEER *>(cursor);
    uapi << "rx_bytes=" << peer->RxBytes << "\n";
    uapi << "tx_bytes=" << peer->TxBytes << "\n";
    if (peer->LastHandshake > kUnixEpochIn100ns) {
      const DWORD64 since_epoch = peer->LastHandshake - kUnixEpochIn100ns;
      uapi << "last_handshake_time_sec=" << since_epoch / k100nsPerSecond << "\n";
      uapi << "last_handshake_time_nsec=" << (since_epoch % k100nsPerSecond) * 100 << "\n";
    } else {
      // No handshake yet, which UAPI also spells as a zero.
      uapi << "last_handshake_time_sec=0\n";
    }
    cursor += sizeof(WIREGUARD_PEER) + static_cast<size_t>(peer->AllowedIPsCount) * sizeof(WIREGUARD_ALLOWED_IP);
  }

  // UAPI closes with the request's result and a blank line. Both are part of
  // the format the parser checks, so a truncated read stays detectable.
  uapi << "errno=0\n\n";
  return uapi.str();
}
}  // namespace

TunnelStatsResult QueryTunnelStats(const std::wstring &adapter_name) {
  // Set on connect and cleared on disconnect, so an empty name means this
  // plugin instance has no tunnel of its own to read.
  if (adapter_name.empty()) {
    return {TunnelStatsStatus::kNoTunnel, "", ""};
  }

  const DriverApi *driver = Driver();
  if (driver == nullptr) {
    return Failure("Could not load the WireGuard driver library.", GetLastError());
  }

  WIREGUARD_ADAPTER_HANDLE adapter = driver->open_adapter(adapter_name.c_str());
  if (adapter == nullptr) {
    const DWORD error_code = GetLastError();
    // The adapter goes away with the tunnel service, so a missing one is the
    // ordinary disconnected state rather than something to report.
    if (error_code == ERROR_FILE_NOT_FOUND || error_code == ERROR_PATH_NOT_FOUND) {
      return {TunnelStatsStatus::kNoTunnel, "", ""};
    }
    return Failure("Could not open the WireGuard adapter.", error_code);
  }

  std::vector<BYTE> buffer(kInitialConfigBytes);
  TunnelStatsResult result = Failure("Could not read the adapter configuration.", 0);
  for (int attempt = 0; attempt < kConfigReadAttempts; attempt++) {
    DWORD bytes = static_cast<DWORD>(buffer.size());
    if (driver->get_configuration(adapter, reinterpret_cast<WIREGUARD_INTERFACE *>(buffer.data()), &bytes)) {
      result = {TunnelStatsStatus::kOk, ToUapi(reinterpret_cast<const WIREGUARD_INTERFACE *>(buffer.data())), ""};
      break;
    }
    const DWORD error_code = GetLastError();
    if (error_code != ERROR_MORE_DATA) {
      result = Failure("Could not read the adapter configuration.", error_code);
      break;
    }
    // The driver leaves the size it needs behind. Retried rather than sized
    // once because a peer can be added between the two calls.
    buffer.resize(bytes);
  }

  driver->close_adapter(adapter);
  return result;
}

}  // namespace wireguard_dart
