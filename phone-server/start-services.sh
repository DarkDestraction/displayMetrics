#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# start-services.sh
# Avvia tutti i servizi del dashboard server
# =============================================================================

PROJ_DIR="$HOME/dashboard-server"
LOG_DIR="$PROJ_DIR/logs"
mkdir -p "$LOG_DIR"

echo "============================================"
echo "  Avvio servizi Dashboard                  "
echo "============================================"

# === 1. InfluxDB ===
echo "[1/3] Avvio InfluxDB..."
if pgrep -x "influxd" > /dev/null; then
    echo "  [OK] InfluxDB gia' in esecuzione"
else
    nohup influxd > "$LOG_DIR/influxdb.log" 2>&1 &
    sleep 2
    if pgrep -x "influxd" > /dev/null; then
        echo "  [OK] InfluxDB avviato (porta 8086)"
    else
        echo "  [ERRORE] InfluxDB non si e' avviato"
        echo "  Controlla: cat $LOG_DIR/influxdb.log"
    fi
fi

# === 2. Grafana ===
echo "[2/3] Avvio Grafana..."
if pgrep -f "grafana-server" > /dev/null; then
    echo "  [OK] Grafana gia' in esecuzione"
else
    nohup grafana-server \
        --homepath $PREFIX/share/grafana \
        --config $PREFIX/etc/grafana.ini \
        > "$LOG_DIR/grafana.log" 2>&1 &
    sleep 3
    if pgrep -f "grafana-server" > /dev/null; then
        echo "  [OK] Grafana avviato (porta 3000)"
    else
        echo "  [ERRORE] Grafana non si e' avviato"
        echo "  Controlla: cat $LOG_DIR/grafana.log"
    fi
fi

# === 3. Script Meteo ===
echo "[3/3] Avvio collector meteo..."
if pgrep -f "weather_collector.py" > /dev/null; then
    echo "  [OK] Weather collector gia' in esecuzione"
else
    nohup python "$PROJ_DIR/scripts/weather_collector.py" > "$LOG_DIR/weather.log" 2>&1 &
    echo "  [OK] Weather collector avviato"
fi

echo ""
echo "============================================"
echo "  Tutti i servizi avviati!                 "
echo "============================================"
echo ""

# Mostra IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Dashboard disponibile su:"
echo "  Grafana:  http://$SERVER_IP:3000"
echo "  InfluxDB: http://$SERVER_IP:8086"
echo ""
echo "Per il Huawei Y6, aprire:"
echo "  http://$SERVER_IP:3000/d/pc-hardware/pc-hardware?kiosk"
echo ""
