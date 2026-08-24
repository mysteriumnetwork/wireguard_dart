#ifndef FLUTTER_PLUGIN_WIREGUARD_DART_PLUGIN_H_
#define FLUTTER_PLUGIN_WIREGUARD_DART_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>

#include "service_control.h"
#include "connection_status_observer.h"

namespace wireguard_dart {

class WireguardDartPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WireguardDartPlugin();

  virtual ~WireguardDartPlugin();

  // Disallow copy and assign.
  WireguardDartPlugin(const WireguardDartPlugin &) = delete;
  WireguardDartPlugin &operator=(const WireguardDartPlugin &) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<ServiceControl> tunnel_service_;
  std::unique_ptr<ConnectionStatusObserver> connection_status_observer_;
  // Basename of the active config file, which is also the tunnel service's UAPI
  // pipe name. Empty while disconnected.
  std::wstring tunnel_name_;
};

}  // namespace wireguard_dart

#endif  // FLUTTER_PLUGIN_WIREGUARD_DART_PLUGIN_H_
