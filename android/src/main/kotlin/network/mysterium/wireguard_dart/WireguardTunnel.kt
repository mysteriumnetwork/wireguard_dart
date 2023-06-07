package network.mysterium.wireguard_dart

import android.util.Log
import androidx.databinding.Bindable
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.Statistics
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class WireguardTunnel internal  constructor(
   private val backend: Backend,
   private var name: String,
   config: Config?,
    state: Tunnel.State,
) : Tunnel{

    override fun getName(): String =
        name


    override fun onStateChange(newState: Tunnel.State) {
        onStateChanged(newState)    }

    @get:Bindable
    var state = state
        private set

    @get:Bindable
    var config = config
        private set

    @get:Bindable
    var statistics: Statistics? = null
        get() {
            if (field == null || field?.isStale != false)
                    try {
                        backend.getStatistics(this@WireguardTunnel)
                    } catch (e: Throwable) {
                        Log.e(TAG, Log.getStackTraceString(e))

                }
            return field
        }
        private set


    fun onStateChanged(state: Tunnel.State): Tunnel.State {
        if (state != Tunnel.State.UP) onStatisticsChanged(null)
        this.state = state
        return state
    }

    private fun onStatisticsChanged(statistics: Statistics?): Statistics? {
        this.statistics = statistics
        return statistics
    }

    companion object {
        private const val TAG = "WireGuard/Tunnel"
    }

    suspend fun getStatisticsAsync(): Statistics = withContext(Dispatchers.Main.immediate) {
        statistics.let {
            if (it == null || it.isStale)
                backend.getStatistics(this@WireguardTunnel)
            else
                it
        }
    }

}