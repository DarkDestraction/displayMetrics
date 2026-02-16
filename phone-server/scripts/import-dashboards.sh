#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# import-dashboards.sh
# Importa tutte le dashboard Grafana automaticamente via API
# Eseguire dopo che Grafana è avviato
# =============================================================================

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARD_DIR="$HOME/dashboard-server/grafana-dashboards"

echo "============================================"
echo "  Importazione Dashboard Grafana           "
echo "============================================"

# === 1. Configura Data Sources ===
echo ""
echo "[1/3] Configurazione Data Sources..."

# Data Source: pc_metrics (metriche PC)
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

# Data Source: weather
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

echo "[OK] Data Sources configurati"

# === 2. Importa Dashboard ===
echo ""
echo "[2/3] Importazione Dashboard..."

for dashboard_file in "$DASHBOARD_DIR"/*.json; do
    if [ ! -f "$dashboard_file" ]; then
        continue
    fi
    
    filename=$(basename "$dashboard_file")
    echo -n "  Importo $filename... "
    
    # Wrappa il JSON della dashboard per l'API di import
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
        echo "OK"
    else
        msg=$(echo "$result" | jq -r '.message // "unknown error"')
        echo "WARN: $msg"
    fi
done

# === 3. Configura Home Dashboard ===
echo ""
echo "[3/3] Configurazione homepage..."

# Imposta la dashboard PC Hardware come homepage
curl -s -X PUT "$GRAFANA_URL/api/org/preferences" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d '{
    "homeDashboardUID": "pc-hardware"
  }' 2>/dev/null | jq -r '.message // "OK"'

# Configura tema scuro (migliore per display always-on)
curl -s -X PUT "$GRAFANA_URL/api/org/preferences" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d '{
    "theme": "dark"
  }' 2>/dev/null | jq -r '.message // "OK"'

echo ""
echo "============================================"
echo "  Importazione completata!                 "
echo "============================================"
echo ""
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Dashboard disponibili:"
echo "  PC Hardware: http://$SERVER_IP:3000/d/pc-hardware/pc-hardware?kiosk"
echo "  Meteo:       http://$SERVER_IP:3000/d/weather/meteo?kiosk"
echo "  Rete:        http://$SERVER_IP:3000/d/network/rete?kiosk"

echo ""
echo "Per il Huawei Y6, usare gli URL sopra con ?kiosk per modalita' fullscreen"
echo ""
