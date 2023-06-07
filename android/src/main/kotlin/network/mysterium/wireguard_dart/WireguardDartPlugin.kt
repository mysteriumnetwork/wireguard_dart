package network.mysterium.wireguard_dart

import android.app.Activity
import android.content.Context
import android.util.Log
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.BadConfigException
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.io.ByteArrayInputStream


private const val TAG = "WireGuard/Application"

/** WireguardDartPlugin */
class WireguardDartPlugin: FlutterPlugin, MethodCallHandler,ActivityAware {

  private lateinit var channel : MethodChannel
  private lateinit var backend: Backend
  private lateinit var context: Context
  private  lateinit var tunnelName: String
  private lateinit var config :com.wireguard.config.Config
  private  lateinit var tunnel: WireguardTunnel
  private  lateinit var activity: Activity
  private val futureBackend = CompletableDeferred<Backend>()





  override fun onAttachedToEngine( flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
      try {
        backend = determineBackend()
        futureBackend.complete(backend)
      } catch (e: Throwable) {
        Log.e(TAG, Log.getStackTraceString(e))

    }

    

    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "wireguard_dart")
    channel.setMethodCallHandler(this)

  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "generateKeyPair" -> {
        generateKeyPair(result)
      }

      "setupTunnel" -> {
        val bundleId: String = call.argument<String>("bundleId").toString()
        setupTunnel(bundleId, result)
      }

      "connect" -> {
        val cfg: String = call.argument<String>("cfg").toString()
        connect(cfg, result)
      }

      "disconnect" -> {
        disconnect(result)

      }

      else -> result.notImplemented()
    }
  }

  private suspend fun getBackend() = futureBackend.await()


  @OptIn(DelicateCoroutinesApi::class)
  private  fun disconnect(result: Result)
  {
    try {
      if (!this::tunnel.isInitialized) {
        throw UninitializedPropertyAccessException()

      }
      else if(tunnel.state == Tunnel.State.DOWN)
      {
        throw  Exception("Tunnel is not running")
      }
      GlobalScope.launch {
        getBackend().setState(tunnel,Tunnel.State.DOWN,config)
        result.success(null)
        return@launch
      }

    }
    catch (e:UninitializedPropertyAccessException)
    {
      result.error("400","Tunnel is not initialized",e)
    }
    catch (e:Exception)
    {
      result.error("400",e.message,e)
    }
  }
  @OptIn(DelicateCoroutinesApi::class)
  private  fun connect(cfg:String, result: Result)
  {
    try {
      val inputStream = ByteArrayInputStream(cfg.toByteArray())
      config =  com.wireguard.config.Config.parse(inputStream)
      GlobalScope.launch {
        tunnel = WireguardTunnel(getBackend(),tunnelName,config,Tunnel.State.DOWN)

        val newState = getBackend().setState(tunnel,Tunnel.State.UP,config)
        tunnel.onStateChanged(newState)

        result.success(null)
        return@launch
      }

    }
    catch (e: BadConfigException)
    {
      result.error("400","Failed to parse config file",e)
    }
    catch (e:Exception)
    {
      result.error("400","Failed to connect",e)

    }
  }



  private fun setupTunnel(bundleId:String, result: Result) {
    if (Tunnel.isNameInvalid(bundleId))
    {
      result.error("400","Invalid Name",IllegalArgumentException() )
    }
    tunnelName  = bundleId
    val intent = GoBackend.VpnService.prepare(activity)
    if(intent != null)
    {
      activity.startActivityForResult(intent,1)
    }
    result.success(null)
    return
  }
  private fun generateKeyPair(result: Result)
  {
    val keyPair = KeyPair()
    val privateKey = keyPair.privateKey.toBase64()
    val publicKey = KeyPair(Key.fromBase64(privateKey)).publicKey.toBase64()
    val map: HashMap<String, String> = hashMapOf("privateKey" to privateKey, "publicKey" to publicKey)
    result.success(map)
    return
  }

  override fun onDetachedFromEngine( binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity

  }

  override fun onDetachedFromActivityForConfigChanges() {

  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
  }

  private fun determineBackend(): Backend {
    return GoBackend(context)
  }
}
