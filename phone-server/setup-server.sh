#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# setup-server.sh
# Script di setup completo per il telefono server (Termux)
# Installa e configura: InfluxDB, Grafana, Python, Node.js
# =============================================================================

echo "============================================"
echo "  Setup Server Dashboard - Termux          "
echo "============================================"
echo ""

# === 1. Aggiornamento pacchetti ===
echo "[1/7] Aggiornamento pacchetti..."
pkg update -y
pkg upgrade -y

# === 2. Installazione pacchetti base ===
echo "[2/7] Installazione pacchetti base..."
pkg install -y \
    wget \
    curl \
    git \
    python \
    nodejs \
    jq \
    net-tools \
    termux-services \
    cronie

# === 3. Installazione InfluxDB ===
echo "[3/7] Installazione InfluxDB..."
if ! command -v influxd &> /dev/null; then
    pkg install -y influxdb
    echo "[OK] InfluxDB installato"
else
    echo "[OK] InfluxDB gia' presente"
fi

# === 4. Installazione Grafana ===
echo "[4/7] Installazione Grafana..."
if ! command -v grafana-server &> /dev/null; then
    pkg install -y grafana
    echo "[OK] Grafana installato"
else
    echo "[OK] Grafana gia' presente"
fi

# === 5. Setup Python per script meteo e monitoraggio ===
echo "[5/7] Setup Python..."
pip install --upgrade pip
pip install requests influxdb-client python-dateutil

# === 6. Creazione directory progetto ===
echo "[6/7] Creazione directory..."
PROJ_DIR="$HOME/dashboard-server"
mkdir -p "$PROJ_DIR/scripts"
mkdir -p "$PROJ_DIR/config"
mkdir -p "$PROJ_DIR/grafana-dashboards"
mkdir -p "$PROJ_DIR/logs"

# === 7. Configurazione InfluxDB ===
echo "[7/7] Configurazione InfluxDB..."

# Avvia InfluxDB temporaneamente per creare il database
influxd &
INFLUX_PID=$!
sleep 3

# Crea database e retention policy
influx -execute "CREATE DATABASE pc_metrics" 2>/dev/null
influx -execute "CREATE RETENTION POLICY \"30days\" ON \"pc_metrics\" DURATION 30d REPLICATION 1 DEFAULT" 2>/dev/null
influx -execute "CREATE DATABASE weather" 2>/dev/null
influx -execute "CREATE RETENTION POLICY \"30days\" ON \"weather\" DURATION 30d REPLICATION 1 DEFAULT" 2>/dev/null
influx -execute "CREATE DATABASE network" 2>/dev/null
influx -execute "CREATE RETENTION POLICY \"30days\" ON \"network\" DURATION 30d REPLICATION 1 DEFAULT" 2>/dev/null
echo "[OK] Database creati: pc_metrics, weather, network"

# Ferma InfluxDB temporaneo
kill $INFLUX_PID 2>/dev/null
wait $INFLUX_PID 2>/dev/null

echo ""
echo "============================================"
echo "  Setup completato!                        "
echo "============================================"
echo ""
echo "Prossimi passi:"
echo "  1. Copiare gli script nella directory $PROJ_DIR/scripts/"
echo "  2. Avviare i servizi: bash start-services.sh"
echo "  3. Configurare Grafana su http://$(hostname -I | awk '{print $1}'):3000"
echo "     User: admin / Password: admin"
echo ""
echo "IP del telefono server: $(hostname -I | awk '{print $1}')"
echo ""
