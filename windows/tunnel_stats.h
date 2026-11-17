#ifndef WIREGUARD_DART_TUNNEL_STATS_H
#define WIREGUARD_DART_TUNNEL_STATS_H

#include <string>

namespace wireguard_dart {

// Outcome of a statistics read.
//
// `kNoTunnel` and `kFailed` are kept apart deliberately: folding an unreadable
// adapter into the same empty result as "nothing is running" is what hid a
// total failure of the Windows counters.
//
// A missing adapter name stays `kNoTunnel` rather than an error, because the
// stats poll also runs while disconnected and reporting that every second would
// drown the signal. A caller that knows it is connected and still sees an empty
// result has its answer by elimination, since every other failure now reports.
enum class TunnelStatsStatus {
  kOk,
  kNoTunnel,
  kFailed,
};

struct TunnelStatsResult {
  TunnelStatsStatus status;
  std::string uapi;   // Set when status is kOk.
  std::string error;  // Set when status is kFailed.
};

// Reads the per-peer counters of the running WireGuard adapter named
// `adapter_name` and renders them in WireGuard's UAPI text format.
//
// The counters come from the WireGuardNT driver rather than a UAPI socket: the
// bundled tunnel service is built on the driver and never opens one. They are
// rendered as UAPI anyway so that one Dart parser covers every platform.
TunnelStatsResult QueryTunnelStats(const std::wstring &adapter_name);

}  // namespace wireguard_dart

#endif  // WIREGUARD_DART_TUNNEL_STATS_H
