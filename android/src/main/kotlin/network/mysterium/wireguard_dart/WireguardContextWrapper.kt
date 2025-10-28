package network.mysterium.wireguard_dart

import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.os.Build


class WireguardContextWrapper(context: Context) : ContextWrapper(context) {
    override fun startService(serviceIntent: Intent?): ComponentName? {

        val ourIntent = Intent(this, WireguardWrapperService::class.java)
        return if (Build.VERSION.SDK_INT >= 26) {
            baseContext.startForegroundService(ourIntent)
        } else {
            baseContext.startService(ourIntent)
        }
    }
}