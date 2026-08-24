#include "uapi_pipe.h"

#include <windows.h>

namespace wireguard_dart {

namespace {
constexpr const wchar_t *kPipePrefix = L"\\\\.\\pipe\\ProtectedPrefix\\Administrators\\WireGuard\\";
constexpr DWORD kPipeWaitMs = 1000;
constexpr const char kGetRequest[] = "get=1\n\n";
}  // namespace

std::optional<std::string> QueryUapi(const std::wstring &tunnel_name) {
  if (tunnel_name.empty()) {
    return std::nullopt;
  }

  const std::wstring pipe_name = std::wstring(kPipePrefix) + tunnel_name;

  HANDLE pipe =
      CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) {
    if (GetLastError() != ERROR_PIPE_BUSY || !WaitNamedPipeW(pipe_name.c_str(), kPipeWaitMs)) {
      return std::nullopt;
    }
    pipe = CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
    if (pipe == INVALID_HANDLE_VALUE) {
      return std::nullopt;
    }
  }

  DWORD written = 0;
  if (!WriteFile(pipe, kGetRequest, sizeof(kGetRequest) - 1, &written, nullptr)) {
    CloseHandle(pipe);
    return std::nullopt;
  }

  std::string response;
  char buffer[4096];
  DWORD read = 0;
  while (ReadFile(pipe, buffer, sizeof(buffer), &read, nullptr) && read > 0) {
    response.append(buffer, read);
    // UAPI terminates its response with a blank line.
    if (response.size() >= 2 && response.compare(response.size() - 2, 2, "\n\n") == 0) {
      break;
    }
  }
  CloseHandle(pipe);

  if (response.empty()) {
    return std::nullopt;
  }
  return response;
}

}  // namespace wireguard_dart
