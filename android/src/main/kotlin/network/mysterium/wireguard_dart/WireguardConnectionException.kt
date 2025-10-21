package network.mysterium.wireguard_dart

class WireguardConnectionException(
    val tunnelName: String,
    val originalException: Exception,
    val details: String
) : Exception("Wireguard connection failed for tunnel '$tunnelName': ${originalException.message}")