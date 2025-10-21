package network.mysterium.wireguard_dart

class PermissionRequestCancelledException :
    Exception("The permission request dialog was closed or the request was cancelled.")