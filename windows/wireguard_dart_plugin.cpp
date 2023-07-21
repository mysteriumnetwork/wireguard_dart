#include "wireguard_dart_plugin.h"

// This must be included before many other Windows headers.
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <libbase64.h>
#include <windows.h>

#include <memory>
#include <sstream>

#include "config_writer.h"
#include "key_generator.h"
#include "service_control.h"
#include "tunnel.h"
#include "utils.h"
#include "wireguard.h"

namespace wireguard_dart {

// static
void WireguardDartPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "wireguard_dart", &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WireguardDartPlugin>();

  channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto &call, auto result) {
    plugin_pointer->HandleMethodCall(call, std::move(result));
  });

  registrar->AddPlugin(std::move(plugin));
}

WireguardDartPlugin::WireguardDartPlugin() {}

WireguardDartPlugin::~WireguardDartPlugin() {}

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
  }

  result->NotImplemented();
}

}  // namespace wireguard_dart
