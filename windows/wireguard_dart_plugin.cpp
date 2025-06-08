#include "wireguard_dart_plugin.h"

// This must be included before many other Windows headers.
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <libbase64.h>
#include <windows.h>

#include <memory>
#include <sstream>

#include "config_writer.h"
#include "connection_status.h"
#include "connection_status_observer.h"
#include "key_generator.h"
#include "service_control.h"
#include "tunnel.h"
#include "utils.h"
#include "wireguard.h"

// Declare the function prototype
std::string GetLastErrorAsString(DWORD error_code);

namespace wireguard_dart {

// static
void WireguardDartPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "wireguard_dart", &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WireguardDartPlugin>();

  channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto &call, auto result) {
    plugin_pointer->HandleMethodCall(call, std::move(result));
  });

  auto status_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "wireguard_dart/status", &flutter::StandardMethodCodec::GetInstance());

  plugin->connection_status_observer_ = std::make_unique<ConnectionStatusObserver>();
  auto status_channel_handler = std::make_unique<flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue *args,
          std::unique_ptr<flutter::EventSink<>> &&events) -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->connection_status_observer_->OnListen(args, std::move(events));
      },
      [plugin_pointer =
           plugin.get()](const flutter::EncodableValue *arguments) -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->connection_status_observer_->OnCancel(arguments);
      });

  status_channel->SetStreamHandler(std::move(status_channel_handler));

  registrar->AddPlugin(std::move(plugin));
}

WireguardDartPlugin::WireguardDartPlugin() {}

WireguardDartPlugin::~WireguardDartPlugin() { this->connection_status_observer_.get()->StopObserving(); }

void WireguardDartPlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &call,
                                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto *args = std::get_if<flutter::EncodableMap>(call.arguments());

  if (call.method_name() == "generateKeyPair") {
    std::pair public_private_keypair = GenerateKeyPair();
    std::map<flutter::EncodableValue, flutter::EncodableValue> return_value;
    return_value[flutter::EncodableValue("publicKey")] = flutter::EncodableValue(public_private_keypair.first);
    return_value[flutter::EncodableValue("privateKey")] = flutter::EncodableValue(public_private_keypair.second);
    result->Success(flutter::EncodableValue(return_value));
    return;
  }

  if (call.method_name() == "checkTunnelConfiguration") {
    auto tunnel_service = this->tunnel_service_.get();
    result->Success(flutter::EncodableValue(tunnel_service != nullptr));
    return;
  }

  if (call.method_name() == "nativeInit") {
    // Disable packet forwarding that conflicts with WireGuard
    ServiceControl remoteAccessService = ServiceControl(L"RemoteAccess");
    try {
      remoteAccessService.Stop();
    } catch (std::exception &e) {
      result->Error(std::string("Could not stop packet forwarding: ").append(e.what()));
      return;
    }
    try {
      remoteAccessService.Disable();
    } catch (std::exception &e) {
      result->Error(std::string("Could not disable packet forwarding: ").append(e.what()));
      return;
    }
    result->Success();
    return;
  }

  if (call.method_name() == "setupTunnel") {
    const auto *arg_service_name = std::get_if<std::string>(ValueOrNull(*args, "win32ServiceName"));
    if (arg_service_name == NULL) {
      result->Error("Argument 'win32ServiceName' is required");
      return;
    }
    if (this->tunnel_service_ != nullptr) {
      // Ensure the observer is started even if the tunnel service already exists
      this->connection_status_observer_.get()->StartObserving(Utf8ToWide(*arg_service_name));
      result->Success();
      return;
    }
    try {
      this->tunnel_service_ = std::make_unique<ServiceControl>(Utf8ToWide(*arg_service_name));
    } catch (const std::exception &e) {
      result->Error("SERVICE_CONTROL_INIT_ERROR", std::string("Failed to initialize ServiceControl: ") + e.what());
      return;
    }
    this->connection_status_observer_.get()->StartObserving(Utf8ToWide(*arg_service_name));

    result->Success();
    return;
  }

  if (call.method_name() == "connect") {
    auto tunnel_service = this->tunnel_service_.get();
    if (tunnel_service == nullptr) {
      result->Error("Invalid state: call 'setupTunnel' first");
      return;
    }
    const auto *cfg = std::get_if<std::string>(ValueOrNull(*args, "cfg"));
    if (cfg == NULL) {
      result->Error("Argument 'cfg' is required");
      return;
    }

    std::wstring wg_config_filename;
    try {
      wg_config_filename = WriteConfigToTempFile(*cfg);
    } catch (std::exception &e) {
      result->Error(std::string("Could not write wireguard config: ").append(e.what()));
      return;
    }

    wchar_t module_filename[MAX_PATH];
    GetModuleFileName(NULL, module_filename, MAX_PATH);
    auto current_exec_dir = std::wstring(module_filename);
    current_exec_dir = current_exec_dir.substr(0, current_exec_dir.find_last_of(L"\\/"));

    std::wostringstream service_exec_builder;
    service_exec_builder << current_exec_dir << "\\wireguard_svc.exe" << L" -service" << L" -config-file=\""
                         << wg_config_filename << "\"";
    std::wstring service_exec = service_exec_builder.str();

    try {
      CreateArgs csa = {};
      csa.description = tunnel_service->service_name_ + L" WireGuard tunnel";
      csa.executable_and_args = service_exec;
      csa.dependencies = L"Nsi\0TcpIp\0";
      tunnel_service->Create(csa);
    } catch (std::exception &e) {
      result->Error(std::string(e.what()));
      return;
    }
    this->connection_status_observer_.get()->StartObserving(L"");
    try {
      tunnel_service->Start();
    } catch (const std::runtime_error &e) {
      // Handle runtime errors with a specific error code and detailed message
      std::string error_message = "Runtime error while starting the tunnel service: ";
      error_message += e.what();
      result->Error("RUNTIME_ERROR", error_message);  // Error code: RUNTIME_ERROR
      return;
    } catch (const std::exception &e) {
      // Handle service exceptions with a specific error code and detailed message
      DWORD error_code = GetLastError();  // Retrieve the last Windows error code
      std::string error_message = "Exception while starting the tunnel service: ";
      error_message += e.what();
      if (error_code != 0) {
        error_message += " Windows Error Code: " + std::to_string(error_code) + ".";
        error_message += " Description: " + GetLastErrorAsString(error_code);
      }
      result->Error("SERVICE_EXCEPTION", error_message);  // Error code: SERVICE_EXCEPTION
      return;
    } catch (...) {
      // Handle unknown exceptions with additional details
      DWORD error_code = GetLastError();  // Retrieve the last Windows error code
      std::string error_message = "An unknown error occurred while starting the tunnel service.";
      if (error_code != 0) {
        error_message += " Windows Error Code: " + std::to_string(error_code) + ".";
        error_message += " Description: " + GetLastErrorAsString(error_code);
      }
      result->Error("UNKNOWN_ERROR", error_message);  // Error code: UNKNOWN_ERROR
      return;
    }
    result->Success();
    return;
  }

  if (call.method_name() == "disconnect") {
    auto tunnel_service = this->tunnel_service_.get();
    if (tunnel_service == nullptr) {
      result->Error("Invalid state: call 'setupTunnel' first");
      return;
    }

    try {
      tunnel_service->Stop();
    } catch (const std::runtime_error &e) {
      // Handle runtime errors with a specific error code and detailed message
      std::string error_message = "Runtime error while stopping the tunnel service: ";
      error_message += e.what();
      result->Error("RUNTIME_ERROR", error_message);  // Error code: RUNTIME_ERROR
      return;
    } catch (const std::exception &e) {
      // Handle service exceptions with a specific error code and detailed message
      DWORD error_code = GetLastError();  // Retrieve the last Windows error code
      std::string error_message = "Exception while stopping the tunnel service: ";
      error_message += e.what();
      if (error_code != 0) {
        error_message += " Windows Error Code: " + std::to_string(error_code) + ".";
        error_message += " Description: " + GetLastErrorAsString(error_code);
      }
      result->Error("SERVICE_EXCEPTION", error_message);  // Error code: SERVICE_EXCEPTION
      return;
    } catch (...) {
      // Handle unknown exceptions with additional details
      DWORD error_code = GetLastError();  // Retrieve the last Windows error code
      std::string error_message = "An unknown error occurred while stopping the tunnel service.";
      if (error_code != 0) {
        error_message += " Windows Error Code: " + std::to_string(error_code) + ".";
        error_message += " Description: " + GetLastErrorAsString(error_code);
      }
      result->Error("UNKNOWN_ERROR", error_message);  // Error code: UNKNOWN_ERROR
      return;
    }

    result->Success();
    return;
  }

  if (call.method_name() == "status") {
    auto tunnel_service = this->tunnel_service_.get();
    if (tunnel_service == nullptr) {
      return result->Success(ConnectionStatusToString(ConnectionStatus::disconnected));
    }

    try {
      auto status = tunnel_service->Status();
      result->Success(ConnectionStatusToString(status));
    } catch (std::exception &e) {
      result->Error(std::string(e.what()));
    }
    return;
  }

  result->NotImplemented();
}

}  // namespace wireguard_dart

std::string GetLastErrorAsString(DWORD error_code) {
  if (error_code == 0) {
    return "No error.";
  }

  LPSTR message_buffer = nullptr;
  size_t size =
      FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL,
                     error_code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPSTR)&message_buffer, 0, NULL);

  std::string message;
  if (size != 0 && message_buffer != nullptr) {
    message.assign(message_buffer, size);
    LocalFree(message_buffer);
  } else {
    message = "Unknown error code: " + std::to_string(error_code);
  }
  return message;
}
