#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# stop-services.sh
# Ferma tutti i servizi del dashboard server
# =============================================================================

echo "Arresto servizi..."

# Weather collector
pkill -f "weather_collector.py" 2>/dev/null && echo "[OK] Weather collector fermato" || echo "[--] Weather collector non attivo"

# Grafana
pkill -f "grafana-server" 2>/dev/null && echo "[OK] Grafana fermato" || echo "[--] Grafana non attivo"

# InfluxDB (fermarlo per ultimo)
pkill -x "influxd" 2>/dev/null && echo "[OK] InfluxDB fermato" || echo "[--] InfluxDB non attivo"

echo ""
echo "Tutti i servizi fermati."
