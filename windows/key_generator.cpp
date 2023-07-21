#include <string>
#include <utility>

#include "libbase64.h"
#include "tunnel.h"

namespace wireguard_dart {

const size_t kKeyLen = 32;
const size_t kBase64BufferSize = kKeyLen * 2;  // Min size = src * 4/3 https://github.com/aklomp/base64#base64_encode

std::pair<std::string, std::string> GenerateKeyPair() {
  char public_key_bytes[kKeyLen];
  char private_key_bytes[kKeyLen];
  WireGuardGenerateKeypair((unsigned char *)public_key_bytes, (unsigned char *)private_key_bytes);

  char b64_buf[kBase64BufferSize];
  size_t b64_output_len;

  base64_encode(public_key_bytes, kKeyLen, b64_buf, &b64_output_len, 0);
  const std::string public_key_b64(b64_buf, 0, b64_output_len);

  base64_encode(private_key_bytes, kKeyLen, b64_buf, &b64_output_len, 0);
  const std::string private_key_b64(b64_buf, 0, b64_output_len);

  return std::make_pair(public_key_b64, private_key_b64);
}

}  // namespace wireguard_dart
