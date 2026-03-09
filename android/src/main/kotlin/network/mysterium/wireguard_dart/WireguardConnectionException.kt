package network.mysterium.wireguard_dart

object WireguardErrorCode {
    const val CONNECTION_FAILED = "ERR_WIREGUARD_CONNECTION"
}

class WireguardConnectionException(
    val tunnelName: String,
    val originalException: Exception,
    val details: String,
    val errorCode: String = WireguardErrorCode.CONNECTION_FAILED
) : Exception("Wireguard connection failed for tunnel '$tunnelName': ${originalException.message}")
