# =============================================================================
# collect-gpu.ps1
# Raccoglie metriche GPU tramite:
#   1. nvidia-smi (GPU NVIDIA)
#   2. Windows GPU Performance Counters (AMD / Intel / qualsiasi GPU)
# =============================================================================

$timestamp = [long](([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds * 1000000000)

# ---- Tentativo 1: NVIDIA via nvidia-smi ----
try {
    $nvidiaSmi = $null
    $paths = @(
        "C:\Windows\System32\nvidia-smi.exe",
        "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
        "nvidia-smi"
    )

    foreach ($path in $paths) {
        if (Get-Command $path -ErrorAction SilentlyContinue) {
            $nvidiaSmi = $path
            break
        }
    }

    if ($nvidiaSmi) {
        $query = "temperature.gpu,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,fan.speed,power.draw,clocks.current.graphics,clocks.current.memory"
        $result = & $nvidiaSmi --query-gpu=$query --format=csv,noheader,nounits 2>$null

        if ($result) {
            $values = $result.Trim().Split(",") | ForEach-Object { $_.Trim() }
            
            if ($values.Count -ge 6) {
                $gpuTemp = $values[0]
                $gpuUtil = $values[1]
                $memUtil = $values[2]
                $memTotal = $values[3]
                $memUsed = $values[4]
                $memFree = $values[5]
                $fanSpeed = if ($values.Count -ge 7 -and $values[6] -ne "[N/A]") { $values[6] } else { "0" }
                $powerDraw = if ($values.Count -ge 8 -and $values[7] -ne "[N/A]") { $values[7] } else { "0" }
                $clockGfx = if ($values.Count -ge 9 -and $values[8] -ne "[N/A]") { $values[8] } else { "0" }
                $clockMem = if ($values.Count -ge 10 -and $values[9] -ne "[N/A]") { $values[9] } else { "0" }

                Write-Output "gpu,source=nvidia temperature=$gpuTemp,utilization=$gpuUtil,memory_utilization=$memUtil,memory_total=${memTotal}i,memory_used=${memUsed}i,memory_free=${memFree}i,fan_speed=$fanSpeed,power_draw=$powerDraw,clock_graphics=${clockGfx}i,clock_memory=${clockMem}i $timestamp"
                exit 0
            }
        }
    }
} catch { }

# ---- Tentativo 2: Windows GPU Performance Counters (AMD, Intel, ecc.) ----
try {
    # Trova la GPU principale (non virtual/spacedesk)
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction Stop |
        Where-Object { $_.Name -notlike '*spacedesk*' -and $_.Name -notlike '*Microsoft*' -and $_.Name -notlike '*Virtual*' } |
        Select-Object -First 1

    if (-not $gpu) { exit 0 }

    $gpuName = $gpu.Name

    # VRAM totale: Win32_VideoController.AdapterRAM è uint32 (max 4GB, overflow per GPU > 4GB)
    # Usiamo il registro di Windows che ha il valore a 64 bit corretto
    $vramTotalMB = 0
    try {
        $regPaths = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -ErrorAction SilentlyContinue
        foreach ($regPath in $regPaths) {
            $qwMem = (Get-ItemProperty $regPath.PSPath -Name "HardwareInformation.qwMemorySize" -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize"
            if ($qwMem -and $qwMem -gt 0) {
                $vramTotalMB = [math]::Round($qwMem / 1MB, 0)
                break
            }
        }
    } catch { }
    # Fallback a AdapterRAM se il registro non funziona
    if ($vramTotalMB -eq 0) {
        $vramTotalMB = [math]::Round($gpu.AdapterRAM / 1MB, 0)
    }

    # Trova il LUID della GPU tramite i contatori
    $allEngines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop

    # Estrai LUID univoci (escludi spacedesk/virtual)
    $spacedeskMem = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPULocalAdapterMemory -ErrorAction SilentlyContinue
    $luids = @{}
    foreach ($engine in $allEngines) {
        if ($engine.Name -match 'luid_(0x[0-9a-f]+_0x[0-9a-f]+)') {
            $luid = $Matches[1]
            if (-not $luids.ContainsKey($luid)) { $luids[$luid] = 0 }
            $luids[$luid]++
        }
    }

    # Scegli il LUID con più engine (la GPU principale)
    $mainLuid = ($luids.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    if (-not $mainLuid) { exit 0 }

    # GPU Utilization: somma per engine fisico (come Task Manager)
    # Task Manager raggruppa per engine (phys_X_eng_Y), somma UtilizationPercentage
    # di tutti i processi su quell'engine, poi mostra il max tra tutti gli engine.
    $gpuEngines = $allEngines | Where-Object { $_.Name -like "*$mainLuid*" }
    $engineUtil = @{}
    foreach ($eng in $gpuEngines) {
        if ($eng.Name -match 'phys_(\d+)_eng_(\d+)_engtype_(\w+)') {
            $key = "phys_$($Matches[1])_eng_$($Matches[2])_engtype_$($Matches[3])"
            if (-not $engineUtil.ContainsKey($key)) { $engineUtil[$key] = [double]0 }
            $engineUtil[$key] += $eng.UtilizationPercentage
        }
    }
    $gpuUtil = 0
    foreach ($val in $engineUtil.Values) {
        if ($val -gt $gpuUtil) { $gpuUtil = $val }
    }
    $gpuUtil = [math]::Min([math]::Round($gpuUtil, 0), 100)

    # VRAM: usa DedicatedUsage da GPUAdapterMemory (più preciso, come Task Manager)
    $vramUsedMB = 0
    try {
        $adapterMem = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction SilentlyContinue
        $gpuAdapterMem = $adapterMem | Where-Object { $_.Name -like "*$mainLuid*" } | Select-Object -First 1
        if ($gpuAdapterMem -and $gpuAdapterMem.DedicatedUsage) {
            $vramUsedMB = [math]::Round($gpuAdapterMem.DedicatedUsage / 1MB, 0)
        }
    } catch { }
    # Fallback a GPULocalAdapterMemory
    if ($vramUsedMB -eq 0) {
        $localMem = $spacedeskMem | Where-Object { $_.Name -like "*$mainLuid*" } | Select-Object -First 1
        if ($localMem) {
            $vramUsedMB = [math]::Round($localMem.LocalUsage / 1MB, 0)
        }
    }
    $vramFreeMB = [math]::Max(0, $vramTotalMB - $vramUsedMB)
    $memUtil = if ($vramTotalMB -gt 0) { [math]::Round(($vramUsedMB / $vramTotalMB) * 100, 0) } else { 0 }

    # GPU Temperature dal sensore hardware_temps (se disponibile, altrimenti 0)
    $gpuTemp = 0

    Write-Output "gpu,source=windows,gpu_name=$($gpuName -replace ' ','_') utilization=$gpuUtil,memory_utilization=$memUtil,memory_total=${vramTotalMB}i,memory_used=${vramUsedMB}i,memory_free=${vramFreeMB}i,fan_speed=0,power_draw=0,clock_graphics=0i,clock_memory=0i $timestamp"
} catch {
    # Silenzioso
    exit 0
}
