#include "wireguard_dart_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include "wireguard.h"
#include "tunnel.h"
#include <libbase64.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace wireguard_dart {

// static
void WireguardDartPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "wireguard_dart",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WireguardDartPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WireguardDartPlugin::WireguardDartPlugin() {}

WireguardDartPlugin::~WireguardDartPlugin() {}

void WireguardDartPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string m = method_call.method_name();
  if (m.compare("generateKeyPair") == 0) {
    const size_t KEY_LEN = 32;
    const size_t B64_BUFFER_SIZE = KEY_LEN * 2; // Min size = src * 4/3 https://github.com/aklomp/base64#base64_encode

    char public_key_bytes[KEY_LEN];
    char private_key_bytes[KEY_LEN];
    WireGuardGenerateKeypair((unsigned char*)public_key_bytes, (unsigned char*)private_key_bytes);

    char b64_buf[B64_BUFFER_SIZE];
    size_t b64_output_len;

    base64_encode(public_key_bytes, KEY_LEN, b64_buf, &b64_output_len, 0);
    const std::string public_key_b64(b64_buf, 0, b64_output_len);

    base64_encode(private_key_bytes, KEY_LEN, b64_buf, &b64_output_len, 0);
    const std::string private_key_b64(b64_buf, 0, b64_output_len);

    std::map<flutter::EncodableValue, flutter::EncodableValue> return_value;
    return_value[flutter::EncodableValue("publicKey")] = flutter::EncodableValue(public_key_b64);
    return_value[flutter::EncodableValue("privateKey")] = flutter::EncodableValue(private_key_b64);

    result->Success(flutter::EncodableValue(return_value));
  } else {
    result->NotImplemented();
  }
}

}  // namespace wireguard_dart
