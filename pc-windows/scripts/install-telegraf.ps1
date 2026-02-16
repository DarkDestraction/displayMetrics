# =============================================================================
# install-telegraf.ps1
# Script di installazione automatica Telegraf su Windows
# Eseguire come Amministratore
# =============================================================================

param(
    [string]$PhoneServerIP = "192.168.1.28"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Installazione Telegraf per Dashboard     " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# === 1. Verifiche preliminari ===
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERRORE] Eseguire questo script come Amministratore!" -ForegroundColor Red
    exit 1
}

# === 2. Creare directory ===
$telegrafDir = "C:\telegraf"
$scriptsDir = "$telegrafDir\scripts"

if (-not (Test-Path $telegrafDir)) {
    New-Item -ItemType Directory -Path $telegrafDir -Force | Out-Null
    Write-Host "[OK] Creata directory $telegrafDir" -ForegroundColor Green
}

if (-not (Test-Path $scriptsDir)) {
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    Write-Host "[OK] Creata directory $scriptsDir" -ForegroundColor Green
}

# === 3. Scaricare Telegraf ===
$telegrafExe = "$telegrafDir\telegraf.exe"
if (-not (Test-Path $telegrafExe)) {
    Write-Host "[INFO] Scaricamento Telegraf..." -ForegroundColor Yellow
    $telegrafUrl = "https://dl.influxdata.com/telegraf/releases/telegraf-1.31.0_windows_amd64.zip"
    $zipPath = "$env:TEMP\telegraf.zip"
    
    try {
        Invoke-WebRequest -Uri $telegrafUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\telegraf_extract" -Force
        
        # Trovare telegraf.exe nella cartella estratta
        $extractedExe = Get-ChildItem -Path "$env:TEMP\telegraf_extract" -Recurse -Filter "telegraf.exe" | Select-Object -First 1
        if ($extractedExe) {
            Copy-Item $extractedExe.FullName -Destination $telegrafExe -Force
            Write-Host "[OK] Telegraf scaricato e installato" -ForegroundColor Green
        } else {
            Write-Host "[ERRORE] telegraf.exe non trovato nell'archivio" -ForegroundColor Red
            exit 1
        }
        
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\telegraf_extract" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[ERRORE] Impossibile scaricare Telegraf: $_" -ForegroundColor Red
        Write-Host "[INFO] Scaricalo manualmente da: https://www.influxdata.com/time-series-platform/telegraf/" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[OK] Telegraf gia' presente" -ForegroundColor Green
}

# === 4. Copiare configurazione ===
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configSource = Join-Path (Split-Path $scriptRoot -Parent) "telegraf\telegraf.conf"

if (Test-Path $configSource) {
    $configContent = Get-Content $configSource -Raw
    $configContent = $configContent -replace "PHONE_SERVER_IP", $PhoneServerIP
    Set-Content -Path "$telegrafDir\telegraf.conf" -Value $configContent
    Write-Host "[OK] Configurazione copiata con IP server: $PhoneServerIP" -ForegroundColor Green
} else {
    Write-Host "[WARN] File telegraf.conf non trovato in $configSource" -ForegroundColor Yellow
    Write-Host "[INFO] Copiare manualmente telegraf.conf in $telegrafDir" -ForegroundColor Yellow
}

# === 5. Copiare scripts di raccolta ===
$scriptFiles = @(
    "collect-hardware-temps.ps1",
    "collect-speedtest.ps1",
    "collect-gpu.ps1"
)

foreach ($script in $scriptFiles) {
    $source = Join-Path (Split-Path $scriptRoot -Parent) "telegraf\scripts\$script"
    if (Test-Path $source) {
        Copy-Item $source -Destination "$scriptsDir\$script" -Force
        Write-Host "[OK] Script copiato: $script" -ForegroundColor Green
    }
}

# === 6. Installare come servizio Windows ===
Write-Host ""
Write-Host "[INFO] Installazione servizio Telegraf..." -ForegroundColor Yellow

# Rimuovere servizio esistente se presente
$existingService = Get-Service -Name telegraf -ErrorAction SilentlyContinue
if ($existingService) {
    Stop-Service telegraf -Force -ErrorAction SilentlyContinue
    & $telegrafExe --service uninstall 2>$null
    Write-Host "[OK] Vecchio servizio rimosso" -ForegroundColor Green
}

& $telegrafExe --service install --config "$telegrafDir\telegraf.conf"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Servizio Telegraf installato" -ForegroundColor Green
    
    # Avviare il servizio
    Start-Service telegraf
    Write-Host "[OK] Servizio Telegraf avviato" -ForegroundColor Green
} else {
    Write-Host "[ERRORE] Impossibile installare il servizio" -ForegroundColor Red
    Write-Host "[INFO] Avviare manualmente: telegraf.exe --config telegraf.conf" -ForegroundColor Yellow
}

# === 7. Test connessione ===
Write-Host ""
Write-Host "[INFO] Test connessione a InfluxDB su $PhoneServerIP..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://${PhoneServerIP}:8086/ping" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Host "[OK] InfluxDB raggiungibile!" -ForegroundColor Green
} catch {
    Write-Host "[WARN] InfluxDB non raggiungibile su $PhoneServerIP" -ForegroundColor Yellow
    Write-Host "[INFO] Assicurarsi che InfluxDB sia avviato sul telefono server" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Installazione completata!                " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prossimi passi:" -ForegroundColor White
Write-Host "  1. Avviare HWiNFO64 in modalita' Sensors-only" -ForegroundColor White
Write-Host "  2. Abilitare 'Shared Memory Support' in HWiNFO" -ForegroundColor White
Write-Host "  3. Verificare che il servizio Telegraf sia attivo:" -ForegroundColor White
Write-Host "     Get-Service telegraf" -ForegroundColor Gray
Write-Host ""
