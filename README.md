# DisplayMetrics – Distributed PC Monitoring System

## Overview

DisplayMetrics è un sistema distribuito per il monitoraggio di metriche hardware e di rete. Raccoglie dati da un PC Windows e li visualizza in tempo reale su un dispositivo mobile (Grafana in kiosk mode). Il progetto integra script PowerShell, Telegraf, InfluxDB e dashboard Grafana per una soluzione LAN‑only.

## Architettura

```text
PC Windows (Telegraf + PowerShell scripts)
        ↓
InfluxDB (Termux server locale)
        ↓
Grafana (Termux)
        ↓
Huawei Display (Browser kiosk mode)
```

## Componenti principali

1. Data Collection (Windows PC)

- `Telegraf` con plugin:
  - `inputs.win_perf` — raccolta contatori di Windows
  - `inputs.exec` — esecuzione di script esterni (PowerShell)

- Script PowerShell (cartella `pc-windows/telegraf/scripts/` o `C:\telegraf\scripts`):
  - `collect-hardware-temps.ps1` — interroga OpenHardwareMonitor/LibreHardwareMonitor (es. `localhost:8085`) per CPU/GPU/SSD temperatures e formatta l'output per InfluxDB.
  - `collect-speedtest.ps1` — esegue `speedtest.exe` e produce download/upload/ping in formato compatibile (line protocol o JSON convertito da Telegraf).
  - Altri script: raccolta `net` (interfacce), `ping_status`, GPU metrics, ecc.

Funzioni chiave:

- Raccolta di sensori hardware e metriche rete
- Parsing e formattazione in Influx Line Protocol
- Invio dati verso InfluxDB remoto (configurazione in `telegraf.conf`)

2. Database Layer

- `InfluxDB` eseguito sul telefono server (Termux)
- Database usato: `pc_metrics`
- Measurements principali:
  - `hardware_temps`
  - `speedtest`
  - `cpu`, `mem`, `disk`, `net`
  - `ping_status`

3. Visualization Layer

- `Grafana` su Termux con dashboard JSON personalizzate (cartella `phone-server/grafana-dashboards/`)
- Visualizzazione sul Huawei in modalità kiosk (Fully Kiosk Browser o browser fullscreen)

## Problemi tecnici affrontati

- Parsing dei dati JSON da OpenHardwareMonitor
- Formattazione corretta in Influx Line Protocol
- Sincronizzazione polling (es. 5s/300s per determinate metriche)
- Debug e comunicazione tra PC Windows e server Termux
- Gestione degli errori negli script PowerShell

## Come avviare il progetto (quickstart)

1. Su PC Windows:

```powershell
# Assumendo Telegraf installato in C:\telegraf
Start-Process -FilePath "C:\telegraf\telegraf.exe"
# Eseguire manualmente uno script per test
powershell -File "C:\telegraf\scripts\collect-speedtest.ps1"
```

2. Su Termux (telefono server):

```bash
# Avvia InfluxDB
influxd &

# Avvia Grafana
grafana-server --homepath $PREFIX/share/grafana &
```

3. Importare dashboard Grafana (opzionale): importare i JSON presenti in `phone-server/grafana-dashboards/` via UI o API.

4. Aprire il browser sul Huawei e puntare all'URL di Grafana (es. `http://IP_TELEFONO_SERVER:3000`) in modalità kiosk.

## File utili nel repository

- `AVVIO-E-STOP.md` — comandi rapidi per avviare/fermare servizi (PC e Termux)
- `phone-server/grafana-dashboards/` — JSON dashboard pronte per import
- `pc-windows/telegraf/` — configurazioni e script Telegraf

## Tecnologie

- PowerShell
- Telegraf
- InfluxDB
- Grafana
- HTML/CSS/JS (frontend visualizzazione)

## Contributore

Scrittura e debug degli script PowerShell per raccolta dati, configurazione Telegraf/InfluxDB, integrazione end‑to‑end e documentazione.

---

Se vuoi, posso:

- inserire esempi di `telegraf.conf` e snippet di script `collect-*` direttamente nel README;
- aggiungere comandi di installazione/auto‑start per Windows e Termux;
- preparare un commit con queste modifiche.
