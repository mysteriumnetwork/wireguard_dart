package network.mysterium.wireguard_dart

class ActivityNotAttachedException :
    Exception("Cannot call method because Activity is not attached to FlutterEngine.")