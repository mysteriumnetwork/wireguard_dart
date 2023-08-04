package network.mysterium.wireguard_dart

import com.wireguard.android.backend.Tunnel

enum class ConnectionStatus {
    disconnected, connected, connecting, disconnecting, unknown;

    companion object {
        fun fromTunnelState(state: Tunnel.State?): ConnectionStatus = when (state) {
            Tunnel.State.UP -> connected
            Tunnel.State.DOWN -> disconnected
            else -> unknown
        }
    }
}