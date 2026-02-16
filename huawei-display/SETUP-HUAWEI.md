# =============================================================================
# Configurazione Huawei Y6 2019 come Display Dashboard
# =============================================================================

## Preparazione iniziale

### 1. Reset di fabbrica (consigliato)
- Impostazioni → Sistema → Ripristina → Ripristino dati di fabbrica
- Questo libera tutta la RAM e storage possibile

### 2. Dopo il reset, configurare:
- Connetti al Wi-Fi della LAN
- NON accedere a Google Account (non necessario)
- Salta tutti i setup opzionali

### 3. Disattivare app inutili
Impostazioni → App → App:
- Disattiva tutte le app preinstallate non necessarie
- Lascia attive solo: Browser, Impostazioni, File Manager

### 4. Impostazioni schermo
- Impostazioni → Display:
  - Luminosità: regolare al minimo confortevole (risparmio batteria)
  - Timeout schermo: MAI (se disponibile) oppure max tempo
  - Rotazione automatica: DISATTIVATA
  - Orientamento: come preferisci (landscape consigliato per dashboard)

### 5. Risparmio energetico
- Impostazioni → Batteria:
  - Disattivare TUTTI i risparmi energetici
  - Disattivare ottimizzazione batteria per il browser
  - Disattivare chiusura app in background

### 6. Rete
- Impostare IP statico:
  - Impostazioni → Wi-Fi → rete → Modifica → Avanzate
  - IP: 192.168.1.11
  - Gateway: 192.168.1.1
  - DNS: 192.168.1.1 (o 8.8.8.8)

---

## Opzione A: Fully Kiosk Browser (CONSIGLIATO)

### Installazione
1. Scaricare da: https://www.fully-kiosk.com/
2. Installare l'APK (abilitare "Origini sconosciute" se necessario)

### Configurazione Fully Kiosk
- **Start URL:** http://192.168.1.28:3000/d/pc-hardware/pc-hardware?kiosk&refresh=10s
- **Web Auto Reload:** Abilitato, ogni 300 secondi
- **Screen Always On:** Abilitato
- **Autostart on Boot:** Abilitato
- **Lock Safe Mode:** Abilitato
- **Rotation:** Landscape
- **Hide Navigation Bar:** Abilitato

#### Per rotazione automatica tra pagine:
Nelle impostazioni "URL Whitelist / Rotation":
```
http://192.168.1.28:3000/d/pc-hardware/pc-hardware?kiosk&refresh=10s
http://192.168.1.28:3000/d/weather/meteo?kiosk&refresh=10m
http://192.168.1.28:3000/d/network/rete?kiosk&refresh=30s
```
- **Rotation Interval:** 30 secondi

---

## Opzione B: Chrome/Browser in modalità fullscreen

Se non vuoi usare Fully Kiosk:

1. Aprire Chrome
2. Navigare a: http://192.168.1.28:3000/d/pc-hardware/pc-hardware?kiosk
3. Menu (⋮) → "Aggiungi a schermata Home"
4. Aprire dalla schermata Home (si apre in fullscreen)

Per la rotazione automatica, usare la pagina HTML fornita:
- Copiare dashboard-viewer.html sul telefono
- Aprirla nel browser

---

## Opzione C: Pagina HTML locale con navigazione

Il file `dashboard-viewer.html` fornito con questo progetto:
1. Ha una barra di navigazione in basso con 4 tab
2. Supporta rotazione automatica tra le pagine
3. Previene lo sleep dello schermo
4. Modalità kiosk incorporata

### Come usarlo:
1. Modificare `PHONE_SERVER_IP` nel file con l'IP reale (es. 192.168.1.28)
2. Copiare il file sul Huawei Y6
3. Aprirlo nel browser
4. Opzionale: "Aggiungi a schermata Home" per fullscreen

---

## Configurazione fisica consigliata

### Posizionamento
- Usare un supporto da scrivania o montare a parete
- Collegare SEMPRE il caricatore (il telefono sarà sempre acceso)
- Orientamento landscape per dashboard migliore

### Cavo e alimentazione
- Usare un caricatore da almeno 1A
- Il telefono può restare sempre collegato
- La batteria potrebbe gonfiarsi nel tempo → monitorare

### Luminosità notturna
- In Fully Kiosk: schedulare luminosità ridotta di notte
- Oppure impostare "Screensaver" con orologio in Fully Kiosk

---

## Risoluzione schermo Huawei Y6 2019
- Display: 6.09" HD+ (1560 x 720)
- Le dashboard Grafana si adattano bene in modalità kiosk
- Consigliato: non più di 6-8 pannelli per pagina per leggibilità

---

## Troubleshooting

### Il telefono si disconnette dal Wi-Fi
- Disattivare "Wi-Fi intelligente" nelle impostazioni Wi-Fi
- Disattivare risparmio energetico Wi-Fi

### Lo schermo si spegne
- Verificare che il timeout sia su "Mai"
- In Fully Kiosk: abilitare "Keep Screen On"
- Abilitare le opzioni sviluppatore e "Stay awake while charging"

### Grafana non si carica
- Verificare che il telefono sia sulla stessa LAN
- Provare: http://192.168.1.28:3000/login nel browser
- Verificare che Grafana sia avviato sul telefono server

### Pagine troppo lente
- Ridurre il refresh rate delle dashboard (da 10s a 30s)
- Ridurre il numero di pannelli per dashboard
- Chiudere tutte le altre app sul Huawei
