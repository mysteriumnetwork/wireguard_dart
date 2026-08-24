#ifndef WIREGUARD_DART_UAPI_PIPE_H
#define WIREGUARD_DART_UAPI_PIPE_H

#include <optional>
#include <string>

namespace wireguard_dart {

// Reads the WireGuard tunnel service's UAPI response for `tunnel_name`, or
// returns nullopt when the pipe is unavailable (tunnel not running, access
// denied, or no response).
std::optional<std::string> QueryUapi(const std::wstring &tunnel_name);

}  // namespace wireguard_dart

#endif  // WIREGUARD_DART_UAPI_PIPE_H
