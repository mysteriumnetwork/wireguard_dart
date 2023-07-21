#ifndef WIREGUARD_DART_KEY_GENERATOR_H
#define WIREGUARD_DART_KEY_GENERATOR_H

#include <string>
#include <utility>

namespace wireguard_dart {

std::pair<std::string, std::string> GenerateKeyPair();

}

#endif
