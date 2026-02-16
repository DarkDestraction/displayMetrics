@echo off
:: ============================================================
::  Avvio automatico Dashboard Monitoring
::  Avvia LibreHardwareMonitor + Telegraf in background
::  Mettere collegamento nella cartella Esecuzione Automatica:
::    Win+R → shell:startup → incolla il collegamento
:: ============================================================

:: --- 1. LibreHardwareMonitor (admin, nascosto nella tray) ---
powershell -WindowStyle Hidden -Command "Start-Process 'C:\Program Files\LibreHardwareMonitor\LibreHardwareMonitor.exe' -Verb RunAs -WindowStyle Hidden"

:: --- Attendi che i sensori siano pronti ---
timeout /t 8 /nobreak >nul

:: --- 2. Telegraf (admin, completamente nascosto) ---
powershell -WindowStyle Hidden -Command "Start-Process 'C:\telegraf\telegraf.exe' -ArgumentList '--config','C:\telegraf\telegraf.conf' -Verb RunAs -WindowStyle Hidden"

exit
