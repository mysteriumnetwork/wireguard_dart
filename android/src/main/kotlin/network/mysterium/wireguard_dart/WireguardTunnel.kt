package network.mysterium.wireguard_dart

import com.wireguard.android.backend.Tunnel

typealias StateChangeCallback = (Tunnel.State) -> Unit

class WireguardTunnel(
    private val name: String,
    private val onStateChanged: StateChangeCallback? = null
) : Tunnel {

    override fun getName(): String = name

    override fun onStateChange(newState: Tunnel.State) {
        onStateChanged?.invoke(newState)
    }
}
