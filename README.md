## Huawei Y6 2019 — Dashboard di Monitoraggio Always‑On

### 1. Obiettivo del progetto
Trasformare un vecchio smartphone (Huawei Y6 2019) in un display always‑on che mostri, in LAN e in tempo reale, dashboard suddivise per pagine:

- Stato hardware PC (CPU, GPU, RAM, SSD, ventole)
- Meteo locale in tempo reale
- Stato rete locale (download/upload, ping, stato connessione)
- Stato server cloud personale (online/offline, servizi attivi)

Tutti i componenti devono funzionare esclusivamente in LAN (nessun accesso esterno richiesto).

---

### 2. Architettura generale

Dispositivi coinvolti:

- **PC Windows** (raccoglie metriche)
- **Telefono server** (Termux — InfluxDB + Grafana)
- **Huawei Y6** (solo visualizzazione in kiosk)

Flusso dati:

PC Windows → Telefono server (InfluxDB) → Grafana → Huawei Y6 (browser in fullscreen)

Il telefono usato come display non esegue alcun calcolo, apre solo le pagine web.

---

### 3. Componenti software principali

- Su PC Windows: HWiNFO64 / OpenHardwareMonitor, Telegraf, Speedtest CLI
- Su Telefono (Termux): InfluxDB, Grafana, (opzionale: Node‑RED, Python)
- Sul Huawei Y6: Fully Kiosk Browser o browser in fullscreen

---

### 4. Configurazione dettagliata (passo‑passo)

#### SEZIONE A — Configurazione PC Windows

##### A.1 Installare

- HWiNFO64: https://www.hwinfo.com/download/
- Telegraf: https://www.influxdata.com/time-series-platform/telegraf/
- Speedtest CLI: https://www.speedtest.net/apps/cli

##### A.2 HWiNFO (sensori)

- Avviare HWiNFO in modalità **Sensors only**
- Abilitare **Shared Memory Support** (o usare OpenHardwareMonitor) per esporre le temperature a Telegraf

##### A.3 Telegraf (config base)

Path di esempio: `C:\telegraf\telegraf.conf`

Esempio (snippet):

```toml
[[inputs.win_perf_counters.object]]
	ObjectName = "Processor"
	Counters = ["% Processor Time"]
	Instances = ["_Total"]

[[inputs.exec]]
	commands = ["powershell -File \"C:\telegraf\scripts\collect-speedtest.ps1\""]
	timeout = "120s"
	interval = "300s"
	data_format = "influx"

[[outputs.influxdb]]
	urls = ["http://IP_TELEFONO_SERVER:8086"]
	database = "pc_metrics"
```

Sostituire `IP_TELEFONO_SERVER` con l'IP reale del Termux server.

##### A.4 Temperature avanzate

- Usare OpenHardwareMonitor o HWiNFO shared memory per leggere CPU/GPU/SSD e inviarle via plugin o script a Telegraf.

##### A.5 Avvio automatico

- Impostare HWiNFO e Telegraf per l'avvio automatico (Telegraf come servizio).

---

#### SEZIONE B — Configurazione Telefono server (Termux)

##### B.1 Installazione base

Da Termux:

```bash
pkg update && pkg upgrade
pkg install influxdb grafana python nodejs
```

##### B.2 InfluxDB

Avvio:

```bash
influxd &
```

Creare DB e retention policy:

```sql
influx
CREATE DATABASE pc_metrics
CREATE RETENTION POLICY "30days" ON "pc_metrics" DURATION 30d REPLICATION 1 DEFAULT
exit
```

##### B.3 Grafana

Avvio:

```bash
grafana-server --homepath $PREFIX/share/grafana &
```

Accesso: `http://IP_TELEFONO_SERVER:3000` (admin password di default)

Collegare Grafana a InfluxDB: Data Sources → InfluxDB → URL `http://localhost:8086` → Database `pc_metrics`.

---

#### SEZIONE C — Creazione dashboard

- **PC**: pannelli per CPU temp, GPU temp, RAM, Disk, Fan (Gauge / Stat / Graph)
- **Meteo**: script Python (Open‑Meteo o OpenWeather) che invia a InfluxDB
- **Rete**: speedtest (download/upload/ping) e storici
- **Server**: ping/servizi (online=1 / offline=0)

---

#### SEZIONE D — Huawei Y6 (display)

- Consigliato: Fully Kiosk Browser
- Impostazioni utili: avvio automatico, schermo sempre acceso, apertura URL Grafana in kiosk mode
- Creare una dashboard Grafana per ciascuna pagina e impostare il browser per ciclare tra gli URL se necessario

---

#### SEZIONE E — Rete locale

- Tutti i dispositivi devono essere nella stessa LAN
- Suggerito: IP statici (es. server `192.168.1.50`, PC `192.168.1.10`, Huawei `192.168.1.20`)

---

#### SEZIONE F — Espansioni future

- Monitor UPS, Stato stampante, sensori IoT, notifiche Telegram, log Windows, stato torrent, calendario

---

### 5. Impatto sulle prestazioni

- PC Windows: CPU <1%, RAM 100–200 MB
- Telefono server: InfluxDB+Grafana ~250–300 MB (30 giorni retention)
- Huawei Y6: solo browser, impatto minimo

---

### 6. Risultato atteso

Un Huawei Y6 trasformato in pannello NOC, sempre acceso, automatico, con dati locali e retention 30 giorni.

---

### File utili nel repository

- `AVVIO-E-STOP.md` — comandi rapidi per avviare/fermare servizi (PC e Termux)
- `phone-server/grafana-dashboards/` — JSON dashboard pronte per import
- `pc-windows/telegraf/` — configurazioni e script Telegraf
