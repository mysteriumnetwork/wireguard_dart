#include "uapi_pipe.h"

#include <windows.h>

namespace wireguard_dart {

namespace {
constexpr const wchar_t *kPipePrefix = L"\\\\.\\pipe\\ProtectedPrefix\\Administrators\\WireGuard\\";
constexpr DWORD kPipeWaitMs = 1000;
constexpr DWORD kIoTimeoutMs = 1000;
constexpr const char kGetRequest[] = "get=1\n\n";

HANDLE OpenPipe(const std::wstring &pipe_name) {
  HANDLE pipe = CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
                            FILE_FLAG_OVERLAPPED, nullptr);
  if (pipe != INVALID_HANDLE_VALUE) {
    return pipe;
  }
  if (GetLastError() != ERROR_PIPE_BUSY || !WaitNamedPipeW(pipe_name.c_str(), kPipeWaitMs)) {
    return INVALID_HANDLE_VALUE;
  }
  return CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED,
                     nullptr);
}

// Waits out one overlapped operation, cancelling it once the deadline passes.
// The caller runs on the platform thread, so a service that accepts the
// connection but never answers must not be able to block it indefinitely.
bool AwaitOverlapped(HANDLE pipe, OVERLAPPED *overlapped, BOOL started, DWORD *transferred) {
  if (!started) {
    if (GetLastError() != ERROR_IO_PENDING) {
      return false;
    }
    if (WaitForSingleObject(overlapped->hEvent, kIoTimeoutMs) != WAIT_OBJECT_0) {
      CancelIoEx(pipe, overlapped);
      return false;
    }
  }
  return GetOverlappedResult(pipe, overlapped, transferred, FALSE) != FALSE;
}

bool IsTerminated(const std::string &response) {
  return response.size() >= 2 && response.compare(response.size() - 2, 2, "\n\n") == 0;
}
}  // namespace

std::optional<std::string> QueryUapi(const std::wstring &tunnel_name) {
  if (tunnel_name.empty()) {
    return std::nullopt;
  }

  HANDLE pipe = OpenPipe(std::wstring(kPipePrefix) + tunnel_name);
  if (pipe == INVALID_HANDLE_VALUE) {
    return std::nullopt;
  }

  HANDLE event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (event == nullptr) {
    CloseHandle(pipe);
    return std::nullopt;
  }

  std::optional<std::string> result;
  OVERLAPPED overlapped{};
  overlapped.hEvent = event;

  DWORD written = 0;
  const BOOL write_started = WriteFile(pipe, kGetRequest, sizeof(kGetRequest) - 1, &written, &overlapped);
  if (AwaitOverlapped(pipe, &overlapped, write_started, &written)) {
    std::string response;
    char buffer[4096];
    while (!IsTerminated(response)) {
      overlapped = OVERLAPPED{};
      overlapped.hEvent = event;
      ResetEvent(event);

      DWORD read = 0;
      const BOOL read_started = ReadFile(pipe, buffer, sizeof(buffer), &read, &overlapped);
      if (!AwaitOverlapped(pipe, &overlapped, read_started, &read) || read == 0) {
        break;
      }
      response.append(buffer, read);
    }
    // UAPI ends its response with a blank line. Anything short of that is a
    // truncated read, and parsing it would report partial counters as if they
    // were complete — including missing the trailing `errno`.
    if (IsTerminated(response)) {
      result = response;
    }
  }

  CloseHandle(event);
  CloseHandle(pipe);
  return result;
}

}  // namespace wireguard_dart
