#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform")
#endif

func nativeFlutterError(message: String) -> FlutterError {
    FlutterError(code: "NATIVE_ERR", message: message, details: nil)
}
