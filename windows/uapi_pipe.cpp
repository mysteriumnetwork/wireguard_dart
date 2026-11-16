#include "uapi_pipe.h"

#include <windows.h>

// Defined in wireguard_dart_plugin.cpp, declared here the same way it is there.
std::string GetLastErrorAsString(DWORD error_code);

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

UapiResult Failure(const std::string &what, DWORD error_code) {
  std::string message = what;
  if (error_code != 0) {
    message += " Windows Error Code: " + std::to_string(error_code) + ".";
    message += " Description: " + GetLastErrorAsString(error_code);
  }
  return {UapiStatus::kFailed, "", message};
}
}  // namespace

UapiResult QueryUapi(const std::wstring &tunnel_name) {
  // Set on connect and cleared on disconnect, so an empty name means this
  // plugin instance has no tunnel of its own to read.
  if (tunnel_name.empty()) {
    return {UapiStatus::kNoTunnel, "", ""};
  }

  HANDLE pipe = OpenPipe(std::wstring(kPipePrefix) + tunnel_name);
  if (pipe == INVALID_HANDLE_VALUE) {
    const DWORD error_code = GetLastError();
    // The service removes the pipe when the tunnel goes down, so a missing one
    // is the ordinary disconnected state rather than something to report.
    if (error_code == ERROR_FILE_NOT_FOUND || error_code == ERROR_PATH_NOT_FOUND) {
      return {UapiStatus::kNoTunnel, "", ""};
    }
    return Failure("Could not open the tunnel service pipe.", error_code);
  }

  HANDLE event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (event == nullptr) {
    const DWORD error_code = GetLastError();
    CloseHandle(pipe);
    return Failure("Could not create the pipe wait event.", error_code);
  }

  UapiResult result{UapiStatus::kFailed, "", ""};
  OVERLAPPED overlapped{};
  overlapped.hEvent = event;

  DWORD written = 0;
  const BOOL write_started = WriteFile(pipe, kGetRequest, sizeof(kGetRequest) - 1, &written, &overlapped);
  if (!AwaitOverlapped(pipe, &overlapped, write_started, &written)) {
    result = Failure("Could not write the UAPI request.", GetLastError());
  } else {
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
      result = {UapiStatus::kOk, response, ""};
    } else {
      result = Failure("The UAPI response was truncated.", 0);
    }
  }

  CloseHandle(event);
  CloseHandle(pipe);
  return result;
}

}  // namespace wireguard_dart
