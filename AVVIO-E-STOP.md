# Avvio e Stop - Dashboard Monitoring

---

## 🖥️ PC WINDOWS

### ▶️ AVVIO (ordine importante)

**1. LibreHardwareMonitor** (serve per le temperature)
- Apri `C:\Program Files\LibreHardwareMonitor\LibreHardwareMonitor.exe`
- Tasto destro → **Esegui come amministratore**
- Vai su: Options → **Remote Web Server** → attivalo (porta 8085)

**2. Telegraf** (raccoglie e invia i dati)
- Apri **PowerShell come Amministratore** (tasto destro su Start → "Terminale (Admin)")
- Esegui:
```powershell
Start-Process -FilePath "C:\telegraf\telegraf.exe" -ArgumentList "--config","C:\telegraf\telegraf.conf" -Verb RunAs
```

### ⏹️ STOP

**Telegraf** — Apri **PowerShell come Amministratore**:
```powershell
Stop-Process -Name "telegraf" -Force
```

Oppure da una shell normale:
```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-Command "Stop-Process -Name telegraf -Force"'
```

**LibreHardwareMonitor** — Chiudi dalla tray icon (icona vicino all'orologio → tasto destro → Exit)

---

## 📱 PHONE SERVER (Termux)

### ▶️ AVVIO (ordine importante)

Apri Termux e esegui:

```bash
# 1. InfluxDB (database)
influxd &

# 2. Grafana (dashboard web)
grafana server --homepath $PREFIX/share/grafana &

# 3. Aspetta che partano
sleep 3

# 4. Collector meteo
cd ~/dashboard-server/scripts
python weather_collector.py &
```

### ⏹️ STOP

```bash
pkill -f weather_collector.py
pkill grafana
pkill influxd
```
Oppure
bash ~/phone-server/stop-services.sh

### 🔍 VERIFICA (controlla che tutto giri)

```bash
pgrep -a influxd && echo "InfluxDB OK" || echo "InfluxDB FERMO"
pgrep -a grafana && echo "Grafana OK" || echo "Grafana FERMO"
pgrep -af weather && echo "Weather OK" || echo "Weather FERMO"
```

---

## 📺 HUAWEI Y6 (Display)

### ▶️ AVVIO
- Apri **Chrome**
- Vai a: `http://192.168.1.28:3000/d/pc-hardware/pc-hardware?kiosk`
- Oppure apri il file `dashboard-viewer.html` salvato sul telefono

### ⏹️ STOP
- Chiudi Chrome

---

## 🔄 RIAVVIO COMPLETO (dopo un riavvio del PC o del telefono)

### Ordine di avvio:
1. **Phone Server** → InfluxDB → Grafana → Collectors
2. **PC** → LibreHardwareMonitor → Telegraf
3. **Huawei** → Apri Chrome

### Ordine di stop:
1. **Huawei** → Chiudi Chrome
2. **PC** → Stop Telegraf → Chiudi LibreHardwareMonitor
3. **Phone Server** → Stop collectors → Stop Grafana → Stop InfluxDB

---

## 📌 NOTE

- **Telegraf** gira come Amministratore, quindi per stopparlo serve PowerShell come Admin
- **InfluxDB** deve partire PRIMA di Grafana e dei collectors
- **LibreHardwareMonitor** deve partire PRIMA di Telegraf (altrimenti le temperature non arrivano)
- Lo speedtest viene eseguito ogni **5 minuti** automaticamente da Telegraf
- I dati meteo vengono aggiornati ogni **10 minuti**
- Se il telefono server si disconnette dal WiFi, i dati smettono di arrivare fino alla riconnessione
