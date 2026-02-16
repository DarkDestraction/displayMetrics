# =============================================================================
# collect-speedtest.ps1
# Esegue speedtest CLI e restituisce risultati in formato InfluxDB line protocol
# =============================================================================

$timestamp = [long](([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds * 1000000000)

try {
    # Percorso speedtest CLI - adattare se installato altrove
    $speedtestPaths = @(
        "C:\telegraf\speedtest.exe",
        "C:\speedtest\speedtest.exe",
        "C:\Program Files\Ookla\Speedtest CLI\speedtest.exe",
        "$env:LOCALAPPDATA\Programs\speedtest\speedtest.exe",
        "speedtest"
    )

    $speedtestExe = $null
    foreach ($path in $speedtestPaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            $speedtestExe = $path
            break
        }
        # Prova anche se è nel PATH
        if (Get-Command $path -ErrorAction SilentlyContinue) {
            $speedtestExe = $path
            break
        }
    }

    if (-not $speedtestExe) {
        Write-Output "speedtest,status=error download=0,upload=0,ping=0,jitter=0 $timestamp"
        exit 0
    }

    $result = & $speedtestExe --format=json --accept-license --accept-gdpr 2>$null | ConvertFrom-Json

    if ($result) {
        # Velocità in Mbps (l'API restituisce bytes/sec)
        $downloadMbps = [math]::Round($result.download.bandwidth * 8 / 1000000, 2)
        $uploadMbps = [math]::Round($result.upload.bandwidth * 8 / 1000000, 2)
        $ping = [math]::Round($result.ping.latency, 2)
        $jitter = [math]::Round($result.ping.jitter, 2)
        $packetLoss = if ($result.packetLoss) { [math]::Round($result.packetLoss, 2) } else { 0 }
        $serverName = $result.server.name -replace '\s+', '_' -replace '[^a-zA-Z0-9_]', ''
        $isp = $result.isp -replace '\s+', '_' -replace '[^a-zA-Z0-9_]', ''

        Write-Output "speedtest,server=$serverName,isp=$isp download_mbps=$downloadMbps,upload_mbps=$uploadMbps,ping_ms=$ping,jitter_ms=$jitter,packet_loss=$packetLoss $timestamp"
    } else {
        Write-Output "speedtest,status=error download_mbps=0,upload_mbps=0,ping_ms=0,jitter_ms=0,packet_loss=0 $timestamp"
    }
} catch {
    Write-Output "speedtest,status=error download_mbps=0,upload_mbps=0,ping_ms=0,jitter_ms=0,packet_loss=0 $timestamp"
}
