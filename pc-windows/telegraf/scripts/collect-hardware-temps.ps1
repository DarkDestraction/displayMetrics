# =============================================================================
# collect-hardware-temps.ps1
# Raccoglie 3 temperature principali da LibreHardwareMonitor Web Server:
#   - CPU Package, GPU Core, Disco (NVMe/SSD)
# LHM deve essere aperto come Admin con Remote Web Server attivo porta 8085
# Output in formato InfluxDB line protocol
# =============================================================================

$timestamp = [long](([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds * 1000000000)
$lhmUrl = "http://localhost:8085/data.json"

function Get-AllSensors($node, $parentPath) {
    $currentPath = if ($parentPath) { "$parentPath > $($node.Text)" } else { $node.Text }

    if ($node.Type -and $node.SensorId -and $node.Value) {
        [PSCustomObject]@{
            Path     = $currentPath
            Name     = $node.Text
            Value    = $node.Value
            SensorId = $node.SensorId
            Type     = $node.Type
        }
    }

    if ($node.Children) {
        foreach ($child in $node.Children) {
            Get-AllSensors $child $currentPath
        }
    }
}

function Parse-Value($valStr) {
    $num = $valStr -replace '[^0-9,.]', ''
    $num = $num -replace ',', '.'
    if ($num -match '^\d+\.?\d*$') { return [double]$num }
    return $null
}

try {
    $response = Invoke-WebRequest -Uri $lhmUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    $data = $response.Content | ConvertFrom-Json
    $sensors = @()
    foreach ($child in $data.Children) {
        $sensors += Get-AllSensors $child ""
    }

    $temps = $sensors | Where-Object { $_.Type -eq "Temperature" }

    # 1. CPU Package (la temperatura generale della CPU)
    $cpuPkg = $temps | Where-Object { $_.SensorId -like "*cpu*" -and $_.Name -like "*Package*" } | Select-Object -First 1
    if (-not $cpuPkg) {
        $cpuPkg = $temps | Where-Object { $_.SensorId -like "*cpu*" -and $_.Name -like "*Core Max*" } | Select-Object -First 1
    }
    if ($cpuPkg) {
        $val = Parse-Value $cpuPkg.Value
        if ($null -ne $val -and $val -gt 0) {
            Write-Output "hardware_temps,sensor=cpu_temp,unit=celsius value=$val $timestamp"
        }
    }

    # 2. GPU Core (la temperatura generale della GPU)
    $gpuCore = $temps | Where-Object { $_.SensorId -like "*gpu*" -and $_.Name -like "*GPU Core*" } | Select-Object -First 1
    if (-not $gpuCore) {
        $gpuCore = $temps | Where-Object { $_.SensorId -like "*gpu*" } | Select-Object -First 1
    }
    if ($gpuCore) {
        $val = Parse-Value $gpuCore.Value
        if ($null -ne $val -and $val -gt 0) {
            Write-Output "hardware_temps,sensor=gpu_temp,unit=celsius value=$val $timestamp"
        }
    }

    # 3. Disco principale (primo NVMe/SSD, solo "Temperature" non warning/critical)
    $diskTemp = $temps | Where-Object {
        ($_.SensorId -like "*nvme*" -or $_.SensorId -like "*hdd*" -or $_.SensorId -like "*storage*") -and
        $_.Name -eq "Temperature"
    } | Select-Object -First 1
    if (-not $diskTemp) {
        $diskTemp = $temps | Where-Object {
            ($_.SensorId -like "*nvme*" -or $_.SensorId -like "*hdd*" -or $_.SensorId -like "*storage*") -and
            $_.Name -notlike "*warning*" -and $_.Name -notlike "*critical*" -and $_.Name -notlike "*Distance*"
        } | Select-Object -First 1
    }
    if ($diskTemp) {
        $val = Parse-Value $diskTemp.Value
        if ($null -ne $val -and $val -gt 0) {
            Write-Output "hardware_temps,sensor=disk_temp,unit=celsius value=$val $timestamp"
        }
    }

} catch {
    Write-Output "hardware_temps,sensor=error,message=lhm_webserver_down value=0 $timestamp"
}
