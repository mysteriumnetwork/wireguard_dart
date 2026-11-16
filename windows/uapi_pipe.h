#ifndef WIREGUARD_DART_UAPI_PIPE_H
#define WIREGUARD_DART_UAPI_PIPE_H

#include <string>

namespace wireguard_dart {

// Outcome of a UAPI read.
//
// `kNoTunnel` and `kFailed` are kept apart deliberately: folding an unreadable
// pipe into the same empty result as "nothing is running" is what hid a total
// failure of the Windows counters.
//
// A missing tunnel name stays `kNoTunnel` rather than an error, because the
// stats poll also runs while disconnected and reporting that every second would
// drown the signal. A caller that knows it is connected and still sees an empty
// result has its answer by elimination, since every other failure now reports.
enum class UapiStatus {
  kOk,
  kNoTunnel,
  kFailed,
};

struct UapiResult {
  UapiStatus status;
  std::string uapi;   // Set when status is kOk.
  std::string error;  // Set when status is kFailed.
};

// Reads the WireGuard tunnel service's UAPI response for `tunnel_name`.
UapiResult QueryUapi(const std::wstring &tunnel_name);

}  // namespace wireguard_dart

#endif  // WIREGUARD_DART_UAPI_PIPE_H
