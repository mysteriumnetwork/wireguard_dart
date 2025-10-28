package network.mysterium.wireguard_dart

data class TunnelStatistics(
    val totalDownload: Long,
    val totalUpload: Long,
    val latestHandshake: Long
)
