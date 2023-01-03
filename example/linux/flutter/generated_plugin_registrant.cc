//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <wireguard_dart/wireguard_dart_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) wireguard_dart_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WireguardDartPlugin");
  wireguard_dart_plugin_register_with_registrar(wireguard_dart_registrar);
}
