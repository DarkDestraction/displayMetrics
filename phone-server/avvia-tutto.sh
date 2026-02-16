#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# avvia-tutto.sh
# Script UNICO da eseguire su Termux per configurare e avviare tutto
# 
# Uso:
#   bash avvia-tutto.sh          # Setup + avvio completo
#   bash avvia-tutto.sh --skip   # Solo avvio (salta setup se gia' fatto)
# =============================================================================

set -e

PROJ_DIR="$HOME/dashboard-server"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJ_DIR/logs"
SETUP_MARKER="$PROJ_DIR/.setup-done"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Dashboard Metrics - Avvio Rapido     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

print_ok()    { echo -e "  ${GREEN}[OK]${NC} $1"; }
print_warn()  { echo -e "  ${YELLOW}[!!]${NC} $1"; }
print_err()   { echo -e "  ${RED}[ERR]${NC} $1"; }
print_step()  { echo -e "\n${CYAN}[$1]${NC} $2"; }

# ─────────────────────────────────────────────────────────────────────────────
# FASE 1: SETUP (solo se non fatto prima o senza --skip)
# ─────────────────────────────────────────────────────────────────────────────
do_setup() {
    print_step "SETUP" "Installazione e configurazione iniziale..."

    # 1. Aggiornamento pacchetti
    print_step "1/6" "Aggiornamento pacchetti..."
    pkg update -y && pkg upgrade -y
    print_ok "Pacchetti aggiornati"

    # 2. Installazione pacchetti
    print_step "2/6" "Installazione pacchetti..."
    pkg install -y wget curl git python nodejs jq net-tools termux-services cronie influxdb grafana
    print_ok "Pacchetti installati"

    # 3. Python deps
    print_step "3/6" "Installazione dipendenze Python..."
    pip install --upgrade pip
    pip install requests influxdb-client python-dateutil
    print_ok "Dipendenze Python pronte"

    # 4. Creazione directory
    print_step "4/6" "Creazione directory progetto..."
    mkdir -p "$PROJ_DIR/scripts"
    mkdir -p "$PROJ_DIR/config"
    mkdir -p "$PROJ_DIR/grafana-dashboards"
    mkdir -p "$LOG_DIR"
    print_ok "Directory create in $PROJ_DIR"

    # 5. Copia file progetto nella directory di lavoro
    print_step "5/6" "Copia file progetto..."
    
    # Copia script
    if [ -f "$SCRIPT_DIR/scripts/weather_collector.py" ]; then
        cp "$SCRIPT_DIR/scripts/weather_collector.py" "$PROJ_DIR/scripts/"
        print_ok "weather_collector.py copiato"
    fi
    if [ -f "$SCRIPT_DIR/scripts/import-dashboards.sh" ]; then
        cp "$SCRIPT_DIR/scripts/import-dashboards.sh" "$PROJ_DIR/scripts/"
        chmod +x "$PROJ_DIR/scripts/import-dashboards.sh"
        print_ok "import-dashboards.sh copiato"
    fi

    # Copia dashboard JSON
    if [ -d "$SCRIPT_DIR/grafana-dashboards" ]; then
        cp "$SCRIPT_DIR/grafana-dashboards/"*.json "$PROJ_DIR/grafana-dashboards/" 2>/dev/null
        print_ok "Dashboard JSON copiate"
    fi

    # Copia gli script di servizio
    for f in start-services.sh stop-services.sh; do
        if [ -f "$SCRIPT_DIR/$f" ]; then
            cp "$SCRIPT_DIR/$f" "$PROJ_DIR/$f"
            chmod +x "$PROJ_DIR/$f"
        fi
    done
    print_ok "Script di servizio copiati"

    # 6. Configurazione InfluxDB (crea database)
    print_step "6/6" "Configurazione InfluxDB..."
    influxd &
    INFLUX_PID=$!
    sleep 3

    influx -execute "CREATE DATABASE pc_metrics" 2>/dev/null || true
    influx -execute "CREATE RETENTION POLICY \"30days\" ON \"pc_metrics\" DURATION 30d REPLICATION 1 DEFAULT" 2>/dev/null || true
    influx -execute "CREATE DATABASE weather" 2>/dev/null || true
    influx -execute "CREATE RETENTION POLICY \"30days\" ON \"weather\" DURATION 30d REPLICATION 1 DEFAULT" 2>/dev/null || true
    influx -execute "CREATE DATABASE network" 2>/dev/null || true
    influx -execute "CREATE RETENTION POLICY \"30days\" ON \"network\" DURATION 30d REPLICATION 1 DEFAULT" 2>/dev/null || true
    print_ok "Database creati: pc_metrics, weather, network"

    kill $INFLUX_PID 2>/dev/null
    wait $INFLUX_PID 2>/dev/null 2>&1
    sleep 1

    # Segna setup come completato
    date > "$SETUP_MARKER"
    print_ok "Setup completato e salvato!"
}

# ─────────────────────────────────────────────────────────────────────────────
# FASE 2: AVVIO SERVIZI
# ─────────────────────────────────────────────────────────────────────────────
do_start_services() {
    print_step "AVVIO" "Avvio di tutti i servizi..."
    mkdir -p "$LOG_DIR"

    # --- InfluxDB ---
    print_step "1/3" "Avvio InfluxDB..."
    if pgrep -x "influxd" > /dev/null; then
        print_ok "InfluxDB gia' in esecuzione"
    else
        nohup influxd > "$LOG_DIR/influxdb.log" 2>&1 &
        sleep 2
        if pgrep -x "influxd" > /dev/null; then
            print_ok "InfluxDB avviato (porta 8086)"
        else
            print_err "InfluxDB non si e' avviato! Controlla: cat $LOG_DIR/influxdb.log"
        fi
    fi

    # --- Grafana ---
    print_step "2/3" "Avvio Grafana..."
    if pgrep -f "grafana-server" > /dev/null; then
        print_ok "Grafana gia' in esecuzione"
    else
        nohup grafana-server \
            --homepath $PREFIX/share/grafana \
            --config $PREFIX/etc/grafana.ini \
            > "$LOG_DIR/grafana.log" 2>&1 &
        sleep 3
        if pgrep -f "grafana-server" > /dev/null; then
            print_ok "Grafana avviato (porta 3000)"
        else
            print_err "Grafana non si e' avviato! Controlla: cat $LOG_DIR/grafana.log"
        fi
    fi

    # --- Weather Collector ---
    print_step "3/3" "Avvio collector meteo..."
    if pgrep -f "weather_collector.py" > /dev/null; then
        print_ok "Weather collector gia' in esecuzione"
    else
        if [ -f "$PROJ_DIR/scripts/weather_collector.py" ]; then
            nohup python "$PROJ_DIR/scripts/weather_collector.py" > "$LOG_DIR/weather.log" 2>&1 &
            sleep 1
            print_ok "Weather collector avviato"
        else
            print_warn "weather_collector.py non trovato, saltato"
        fi
    fi

    print_ok "Tutti i servizi avviati!"
}

# ─────────────────────────────────────────────────────────────────────────────
# FASE 3: IMPORTAZIONE DASHBOARD (solo al primo avvio)
# ─────────────────────────────────────────────────────────────────────────────
do_import_dashboards() {
    IMPORT_MARKER="$PROJ_DIR/.dashboards-imported"

    if [ -f "$IMPORT_MARKER" ]; then
        print_ok "Dashboard gia' importate in precedenza (elimina $IMPORT_MARKER per reimportare)"
        return
    fi

    print_step "IMPORT" "Importazione dashboard Grafana..."

    GRAFANA_URL="http://localhost:3000"
    GRAFANA_USER="admin"
    GRAFANA_PASS="admin"
    DASHBOARD_DIR="$PROJ_DIR/grafana-dashboards"

    # Attendi che Grafana sia pronto
    echo -n "  Attendo Grafana..."
    for i in $(seq 1 15); do
        if curl -s "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
            echo " pronto!"
            break
        fi
        echo -n "."
        sleep 2
    done

    # Configura Data Sources
    echo "  Configurazione Data Sources..."
    curl -s -X POST "$GRAFANA_URL/api/datasources" \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d '{
            "name": "InfluxDB - PC Metrics",
            "type": "influxdb",
            "uid": "influxdb",
            "url": "http://localhost:8086",
            "database": "pc_metrics",
            "access": "proxy",
            "isDefault": true
        }' 2>/dev/null | jq -r '.message // "OK"'

    curl -s -X POST "$GRAFANA_URL/api/datasources" \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d '{
            "name": "InfluxDB - Weather",
            "type": "influxdb",
            "uid": "influxdb-weather",
            "url": "http://localhost:8086",
            "database": "weather",
            "access": "proxy"
        }' 2>/dev/null | jq -r '.message // "OK"'

    curl -s -X POST "$GRAFANA_URL/api/datasources" \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d '{
            "name": "InfluxDB - Network",
            "type": "influxdb",
            "uid": "influxdb-network",
            "url": "http://localhost:8086",
            "database": "network",
            "access": "proxy"
        }' 2>/dev/null | jq -r '.message // "OK"'

    print_ok "Data Sources configurati"

    # Importa Dashboard JSON
    for dashboard_file in "$DASHBOARD_DIR"/*.json; do
        [ ! -f "$dashboard_file" ] && continue

        filename=$(basename "$dashboard_file")
        echo -n "  Importo $filename... "

        dashboard_json=$(cat "$dashboard_file")
        import_payload=$(cat <<EOF
{
  "dashboard": $dashboard_json,
  "overwrite": true,
  "folderId": 0
}
EOF
)
        result=$(curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
            -H "Content-Type: application/json" \
            -u "$GRAFANA_USER:$GRAFANA_PASS" \
            -d "$import_payload" 2>/dev/null)

        status=$(echo "$result" | jq -r '.status // "error"')
        if [ "$status" = "success" ]; then
            echo -e "${GREEN}OK${NC}"
        else
            msg=$(echo "$result" | jq -r '.message // "unknown error"')
            echo -e "${YELLOW}WARN: $msg${NC}"
        fi
    done

    # Tema scuro + homepage
    curl -s -X PUT "$GRAFANA_URL/api/org/preferences" \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d '{"homeDashboardUID": "pc-hardware", "theme": "dark"}' 2>/dev/null > /dev/null

    date > "$IMPORT_MARKER"
    print_ok "Dashboard importate!"
}

# ─────────────────────────────────────────────────────────────────────────────
# FASE 4: RIEPILOGO FINALE
# ─────────────────────────────────────────────────────────────────────────────
print_summary() {
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$SERVER_IP" ] && SERVER_IP=$(ifconfig 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
    [ -z "$SERVER_IP" ] && SERVER_IP="<IP-TELEFONO>"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         TUTTO PRONTO!                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Grafana:${NC}         http://$SERVER_IP:3000"
    echo -e "  ${CYAN}InfluxDB:${NC}        http://$SERVER_IP:8086"
    echo ""
    echo -e "  ${CYAN}Dashboard Kiosk:${NC}"
    echo "    PC Hardware:   http://$SERVER_IP:3000/d/pc-hardware/pc-hardware?kiosk"
    echo "    Meteo:         http://$SERVER_IP:3000/d/weather/meteo?kiosk"
    echo "    Rete:          http://$SERVER_IP:3000/d/network/rete?kiosk"
    echo ""
    echo -e "  ${YELLOW}Per fermare tutto:${NC}"
    echo "    bash $PROJ_DIR/stop-services.sh"
    echo ""
    echo -e "  ${YELLOW}Per riavviare (senza reinstallare):${NC}"
    echo "    bash avvia-tutto.sh --skip"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
print_banner

# Controlla se skipare il setup
SKIP_SETUP=false
if [ "$1" = "--skip" ] || [ "$1" = "-s" ]; then
    SKIP_SETUP=true
fi

# Acquisisci wakelock per evitare che Termux venga killato
termux-wake-lock 2>/dev/null && print_ok "Wake lock acquisito (il telefono restera' attivo)" || true

# FASE 1: Setup
if [ "$SKIP_SETUP" = true ]; then
    if [ -f "$SETUP_MARKER" ]; then
        print_ok "Setup saltato (gia' fatto il $(cat $SETUP_MARKER))"
    else
        print_warn "Setup mai eseguito! Eseguo setup completo..."
        do_setup
    fi
elif [ -f "$SETUP_MARKER" ]; then
    print_ok "Setup gia' fatto il $(cat $SETUP_MARKER), salto (usa --skip per forzare)"
else
    do_setup
fi

# FASE 2: Avvio servizi
do_start_services

# FASE 3: Import dashboard
do_import_dashboards

# FASE 4: Riepilogo
print_summary
