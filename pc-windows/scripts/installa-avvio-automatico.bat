@echo off
:: ============================================================
::  Installa il task di avvio automatico nel Task Scheduler
::  ESEGUIRE UNA SOLA VOLTA come Amministratore
:: ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRORE] Eseguire come Amministratore!
    echo Tasto destro sul file -^> Esegui come amministratore
    pause
    exit /b 1
)

echo ============================================
echo   Installazione avvio automatico...
echo ============================================
echo.

:: Percorso del bat di avvio
set "BAT_PATH=C:\telegraf\avvio-dashboard.bat"

:: Copia il bat di avvio in C:\telegraf (posizione stabile)
echo [1/3] Copiando script di avvio...
copy /Y "%~dp0avvio-dashboard.bat" "%BAT_PATH%" >nul
echo       OK: %BAT_PATH%

:: Crea il task schedulato (admin, senza UAC, all'accesso)
echo [2/3] Creando task pianificato...
schtasks /Delete /TN "DashboardMonitoring" /F >nul 2>&1
schtasks /Create /TN "DashboardMonitoring" /TR "\"%BAT_PATH%\"" /SC ONLOGON /RL HIGHEST /F /DELAY 0000:10
echo       OK: Task "DashboardMonitoring" creato

echo [3/3] Verifica...
schtasks /Query /TN "DashboardMonitoring" /FO LIST | findstr "Nome Status"
echo.
echo ============================================
echo   FATTO! Al prossimo avvio di Windows
echo   la dashboard partira' automaticamente
echo   senza popup UAC.
echo ============================================
echo.
echo   Per rimuovere:
echo   schtasks /Delete /TN "DashboardMonitoring" /F
echo.
pause
