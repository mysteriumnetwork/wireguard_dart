package network.mysterium.wireguard_dart

import android.accounts.AccountManager.get
import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.WgQuickBackend
import com.wireguard.android.util.RootShell

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking

private const val TAG = "WireGuard/Application"

/** WireguardDartPlugin */
class WireguardDartPlugin: FlutterPlugin, MethodCallHandler,ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private val futureBackend = CompletableDeferred<Backend>()
  private var backend: Backend? = null
  private lateinit var context: Context
  private lateinit var activity: Activity
  private lateinit var rootShell: RootShell




  override fun onAttachedToEngine( flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext;
      try {
        backend = determineBackend()
        futureBackend.complete(backend!!)

      } catch (e: Throwable) {
        Log.e(TAG, Log.getStackTraceString(e))

    }

    

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "wireguard_dart")
    channel.setMethodCallHandler(this)

  }

  override fun onMethodCall( call: MethodCall,  result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine( binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {
    TODO("Not yet implemented")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    TODO("Not yet implemented")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity;
  }

  override fun onDetachedFromActivityForConfigChanges() {
    TODO("Not yet implemented")
  }

  private  fun determineBackend(): Backend {

    return GoBackend(context)
  }
}
