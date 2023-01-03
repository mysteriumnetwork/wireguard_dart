#import "WireguardDartPlugin.h"
#if __has_include(<wireguard_dart/wireguard_dart-Swift.h>)
#import <wireguard_dart/wireguard_dart-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "wireguard_dart-Swift.h"
#endif

@implementation WireguardDartPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftWireguardDartPlugin registerWithRegistrar:registrar];
}
@end
