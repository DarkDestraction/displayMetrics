# =============================================================================
# invia-a-termux.ps1
# Invia tutti i file del phone-server al telefono Termux via WiFi (SCP)
#
# PREREQUISITI:
#   1. PC e telefono sulla stessa rete WiFi
#   2. Su Termux eseguire PRIMA:
#        pkg install openssh -y
#        passwd          (imposta una password)
#        sshd            (avvia il server SSH)
#        ifconfig        (annota l'IP del telefono)
#
# USO:
#   .\invia-a-termux.ps1 -IP 192.168.1.XXX
#   .\invia-a-termux.ps1                     (ti chiede l'IP)
# =============================================================================

param(
    [string]$IP
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Invio file a Termux via WiFi (SCP)       " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Chiedi IP se non fornito ---
if (-not $IP) {
    $IP = Read-Host "Inserisci l'IP del telefono (es. 192.168.1.100)"
}

if (-not $IP) {
    Write-Host "[ERRORE] IP non fornito. Annullato." -ForegroundColor Red
    exit 1
}

$PORT = 8022
$USER = "u0_a" # L'utente Termux si scopre con 'whoami' - verra' chiesto

Write-Host ""
Write-Host "Su Termux, esegui 'whoami' per vedere il tuo username." -ForegroundColor Yellow
$USER = Read-Host "Username Termux (default: $(whoami) -> premi invio per usare il default mostrato da Termux)"
if (-not $USER) {
    Write-Host "[ERRORE] Devi inserire l'username di Termux (esegui 'whoami' su Termux)." -ForegroundColor Red
    exit 1
}

$DEST = "${USER}@${IP}"
$REMOTE_DIR = "~/phone-server"

# --- Trova la cartella phone-server locale ---
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
# Lo script e' in pc-windows/scripts/, phone-server e' 2 livelli sopra
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$PhoneServerDir = Join-Path $ProjectRoot "phone-server"

if (-not (Test-Path $PhoneServerDir)) {
    # Prova path alternativo
    $PhoneServerDir = Join-Path $ScriptRoot "..\..\phone-server"
    if (-not (Test-Path $PhoneServerDir)) {
        Write-Host "[ERRORE] Cartella phone-server non trovata!" -ForegroundColor Red
        Write-Host "  Cercato in: $PhoneServerDir" -ForegroundColor Red
        exit 1
    }
}

$PhoneServerDir = (Resolve-Path $PhoneServerDir).Path
Write-Host ""
Write-Host "[INFO] Cartella sorgente: $PhoneServerDir" -ForegroundColor Gray
Write-Host "[INFO] Destinazione:      $DEST`:$REMOTE_DIR (porta $PORT)" -ForegroundColor Gray
Write-Host ""

# --- Test connessione ---
Write-Host "[1/4] Test connessione SSH..." -ForegroundColor Cyan
try {
    $testResult = ssh -p $PORT -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes $DEST "echo OK" 2>&1
    if ($testResult -match "OK") {
        Write-Host "  [OK] Connessione riuscita!" -ForegroundColor Green
    } else {
        throw "Connessione fallita"
    }
} catch {
    Write-Host "  [!!] Primo accesso - ti verra' chiesta la password di Termux." -ForegroundColor Yellow
    Write-Host "       (Quella impostata con 'passwd' su Termux)" -ForegroundColor Yellow
}

# --- Crea directory remota ---
Write-Host "[2/4] Creazione directory su Termux..." -ForegroundColor Cyan
ssh -p $PORT -o StrictHostKeyChecking=no $DEST "mkdir -p $REMOTE_DIR/scripts $REMOTE_DIR/grafana-dashboards $REMOTE_DIR/logs"
Write-Host "  [OK] Directory create" -ForegroundColor Green

# --- Invio file ---
Write-Host "[3/4] Invio file..." -ForegroundColor Cyan

$filesToSend = @(
    @{ Local = "avvia-tutto.sh";                         Remote = "$REMOTE_DIR/" },
    @{ Local = "setup-server.sh";                        Remote = "$REMOTE_DIR/" },
    @{ Local = "start-services.sh";                      Remote = "$REMOTE_DIR/" },
    @{ Local = "stop-services.sh";                       Remote = "$REMOTE_DIR/" },
    @{ Local = "prepara-ssh.sh";                         Remote = "$REMOTE_DIR/" },
    @{ Local = "scripts\weather_collector.py";           Remote = "$REMOTE_DIR/scripts/" },
    @{ Local = "scripts\import-dashboards.sh";           Remote = "$REMOTE_DIR/scripts/" },
    @{ Local = "grafana-dashboards\pc-hardware.json";    Remote = "$REMOTE_DIR/grafana-dashboards/" },
    @{ Local = "grafana-dashboards\network.json";        Remote = "$REMOTE_DIR/grafana-dashboards/" },
    @{ Local = "grafana-dashboards\weather.json";        Remote = "$REMOTE_DIR/grafana-dashboards/" }
)

$success = 0
$failed = 0

foreach ($file in $filesToSend) {
    $localPath = Join-Path $PhoneServerDir $file.Local
    if (Test-Path $localPath) {
        Write-Host "  Invio $($file.Local)... " -NoNewline
        try {
            scp -P $PORT -o StrictHostKeyChecking=no $localPath "${DEST}:$($file.Remote)"
            Write-Host "OK" -ForegroundColor Green
            $success++
        } catch {
            Write-Host "ERRORE" -ForegroundColor Red
            $failed++
        }
    } else {
        Write-Host "  [SKIP] $($file.Local) non trovato" -ForegroundColor Yellow
    }
}

# --- Rendi eseguibili gli script ---
Write-Host "[4/4] Impostazione permessi..." -ForegroundColor Cyan
ssh -p $PORT -o StrictHostKeyChecking=no $DEST "chmod +x $REMOTE_DIR/*.sh $REMOTE_DIR/scripts/*.sh 2>/dev/null; echo OK"
Write-Host "  [OK] Script resi eseguibili" -ForegroundColor Green

# --- Riepilogo ---
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Trasferimento completato!                " -ForegroundColor Green
Write-Host "  File inviati: $success  |  Errori: $failed" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Ora su Termux esegui:" -ForegroundColor Yellow
Write-Host "    cd ~/phone-server" -ForegroundColor White
Write-Host "    bash avvia-tutto.sh" -ForegroundColor White
Write-Host ""
Write-Host "  Questo fara' setup + avvio di tutto automaticamente!" -ForegroundColor Gray
Write-Host ""
