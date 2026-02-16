#!/usr/bin/env python3
# =============================================================================
# weather_collector.py
# Raccoglie dati meteo da Open-Meteo (GRATIS, nessuna API key necessaria)
# e li invia a InfluxDB
# Eseguire sul telefono server (Termux)
# =============================================================================
#
# CONFIGURAZIONE:
# Impostare solo latitudine, longitudine e nome citta' qui sotto.
# Per trovare le coordinate: cerca la tua citta' su Google Maps,
# clicca col destro sulla mappa e copia lat/lon.
# =============================================================================

import requests
import time
import sys
from datetime import datetime

# ===================== CONFIGURAZIONE =====================
# Coordinate della tua citta' (cerca su Google Maps)
LATITUDE = 45.5956       # Oleggio (NO)
LONGITUDE = 8.6342        # Oleggio (NO)
CITY_NAME = "Oleggio"     # Nome per etichetta

INFLUXDB_URL = "http://localhost:8086"
INFLUXDB_DB = "weather"
COLLECTION_INTERVAL = 600  # Secondi (600 = 10 minuti)

# Codici meteo WMO -> descrizione italiana
WMO_CODES = {
    0: "Sereno",
    1: "Prevalentemente_sereno",
    2: "Parzialmente_nuvoloso",
    3: "Coperto",
    45: "Nebbia",
    48: "Nebbia_gelata",
    51: "Pioggerella_leggera",
    53: "Pioggerella_moderata",
    55: "Pioggerella_intensa",
    56: "Pioggerella_gelata_leggera",
    57: "Pioggerella_gelata_intensa",
    61: "Pioggia_leggera",
    63: "Pioggia_moderata",
    65: "Pioggia_intensa",
    66: "Pioggia_gelata_leggera",
    67: "Pioggia_gelata_intensa",
    71: "Neve_leggera",
    73: "Neve_moderata",
    75: "Neve_intensa",
    77: "Granelli_di_neve",
    80: "Rovesci_leggeri",
    81: "Rovesci_moderati",
    82: "Rovesci_violenti",
    85: "Rovesci_neve_leggeri",
    86: "Rovesci_neve_intensi",
    95: "Temporale",
    96: "Temporale_con_grandine_leggera",
    99: "Temporale_con_grandine_intensa",
}
# ==========================================================


def get_current_weather():
    """Ottiene meteo attuale da Open-Meteo (gratis, no API key)"""
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "current": "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m",
        "timezone": "auto"
    }

    response = requests.get(url, params=params, timeout=15)
    response.raise_for_status()
    return response.json()


def get_forecast():
    """Ottiene previsioni orarie prossime 24h da Open-Meteo"""
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "hourly": "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m",
        "forecast_hours": 24,
        "timezone": "auto"
    }

    response = requests.get(url, params=params, timeout=15)
    response.raise_for_status()
    return response.json()


def get_daily_info():
    """Ottiene alba, tramonto e min/max giornaliere"""
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max",
        "forecast_days": 1,
        "timezone": "auto"
    }

    response = requests.get(url, params=params, timeout=15)
    response.raise_for_status()
    return response.json()


def write_to_influxdb(measurement, tags, fields, timestamp=None):
    """Scrive un punto dati in InfluxDB usando line protocol"""
    tag_str = ",".join([f"{k}={v}" for k, v in tags.items()])
    field_str = ",".join([f"{k}={v}" for k, v in fields.items()])

    if tag_str:
        line = f"{measurement},{tag_str} {field_str}"
    else:
        line = f"{measurement} {field_str}"

    if timestamp:
        line += f" {timestamp}"

    url = f"{INFLUXDB_URL}/write"
    params = {"db": INFLUXDB_DB, "precision": "s"}

    response = requests.post(url, params=params, data=line, timeout=10)
    if response.status_code not in [200, 204]:
        print(f"[ERRORE] InfluxDB write: {response.status_code} - {response.text}")
        return False
    return True


def collect_and_store():
    """Raccoglie e salva tutti i dati meteo"""
    try:
        # === Meteo attuale ===
        data = get_current_weather()
        current = data["current"]

        weather_code = int(current.get("weather_code", 0))
        description = WMO_CODES.get(weather_code, "Sconosciuto")

        tags = {
            "city": CITY_NAME.replace(" ", "_")
        }

        fields = {
            "temperature": float(current["temperature_2m"]),
            "feels_like": float(current["apparent_temperature"]),
            "humidity": float(current["relative_humidity_2m"]),
            "pressure": float(current["pressure_msl"]),
            "surface_pressure": float(current["surface_pressure"]),
            "wind_speed": float(current["wind_speed_10m"]),
            "wind_deg": float(current["wind_direction_10m"]),
            "wind_gusts": float(current["wind_gusts_10m"]),
            "clouds": float(current["cloud_cover"]),
            "precipitation": float(current["precipitation"]),
            "rain": float(current["rain"]),
            "snowfall": float(current["snowfall"]),
            "weather_code": float(weather_code),
            "description": f'"{description}"'
        }

        # Aggiungi min/max e alba/tramonto dal daily
        try:
            daily_data = get_daily_info()
            daily = daily_data.get("daily", {})
            if daily.get("temperature_2m_max"):
                fields["temp_max"] = float(daily["temperature_2m_max"][0])
            if daily.get("temperature_2m_min"):
                fields["temp_min"] = float(daily["temperature_2m_min"][0])
            if daily.get("uv_index_max"):
                fields["uv_index"] = float(daily["uv_index_max"][0])
            if daily.get("precipitation_sum"):
                fields["precipitation_daily"] = float(daily["precipitation_sum"][0])
            if daily.get("sunrise") and daily["sunrise"][0]:
                # Converti stringa ISO a timestamp
                sunrise_dt = datetime.fromisoformat(daily["sunrise"][0])
                fields["sunrise"] = f'"{sunrise_dt.strftime("%H:%M")}"'
            if daily.get("sunset") and daily["sunset"][0]:
                sunset_dt = datetime.fromisoformat(daily["sunset"][0])
                fields["sunset"] = f'"{sunset_dt.strftime("%H:%M")}"'
        except Exception as e:
            print(f"[WARN] Errore dati giornalieri: {e}")

        write_to_influxdb("current_weather", tags, fields)
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Meteo: {current['temperature_2m']}°C, {description}, umidita' {current['relative_humidity_2m']}%")

        # === Previsioni orarie ===
        try:
            forecast_data = get_forecast()
            hourly = forecast_data.get("hourly", {})
            times = hourly.get("time", [])

            for i, time_str in enumerate(times):
                forecast_tags = {
                    "city": CITY_NAME.replace(" ", "_"),
                    "type": "forecast"
                }

                fc_code = int(hourly["weather_code"][i]) if hourly.get("weather_code") else 0
                fc_desc = WMO_CODES.get(fc_code, "Sconosciuto")

                forecast_fields = {
                    "temperature": float(hourly["temperature_2m"][i]),
                    "feels_like": float(hourly["apparent_temperature"][i]),
                    "humidity": float(hourly["relative_humidity_2m"][i]),
                    "pressure": float(hourly["pressure_msl"][i]),
                    "wind_speed": float(hourly["wind_speed_10m"][i]),
                    "clouds": float(hourly["cloud_cover"][i]),
                    "precipitation": float(hourly["precipitation"][i]),
                    "pop": float(hourly["precipitation_probability"][i]),
                    "weather_code": float(fc_code),
                    "description": f'"{fc_desc}"'
                }

                # Converti timestamp ISO a Unix epoch
                dt = datetime.fromisoformat(time_str)
                epoch = int(dt.timestamp())

                write_to_influxdb("weather_forecast", forecast_tags, forecast_fields, timestamp=epoch)

            print(f"[{datetime.now().strftime('%H:%M:%S')}] Previsioni: {len(times)} ore salvate")
        except Exception as e:
            print(f"[WARN] Errore previsioni: {e}")

    except requests.exceptions.RequestException as e:
        print(f"[ERRORE] Connessione API meteo: {e}")
    except Exception as e:
        print(f"[ERRORE] Generico: {e}")


def main():
    print(f"Weather Collector avviato (Open-Meteo, gratis)")
    print(f"  Citta': {CITY_NAME}")
    print(f"  Coordinate: {LATITUDE}, {LONGITUDE}")
    print(f"  Intervallo: {COLLECTION_INTERVAL}s")
    print(f"  InfluxDB: {INFLUXDB_URL}/{INFLUXDB_DB}")
    print("")

    # Prima raccolta immediata
    collect_and_store()

    while True:
        time.sleep(COLLECTION_INTERVAL)
        collect_and_store()


if __name__ == "__main__":
    main()
