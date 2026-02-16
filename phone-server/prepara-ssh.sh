#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# prepara-ssh.sh
# Da eseguire UNA VOLTA su Termux per abilitare la ricezione file via WiFi
#
# Uso: copia-incolla questo nel terminale Termux:
#   pkg install openssh -y; sshd; whoami; ifconfig | grep -oP 'inet \K[\d.]+'
#
# Poi dal PC lancia: invia-a-termux.ps1
# =============================================================================

echo "============================================"
echo "  Preparazione SSH su Termux               "
echo "============================================"

# Installa OpenSSH
pkg install -y openssh

# Imposta password per l'utente Termux
echo ""
echo "Imposta una password per ricevere i file:"
passwd

# Avvia server SSH (porta 8022)
sshd

echo ""
echo "============================================"
echo "  SSH PRONTO!                              "
echo "============================================"
echo ""
echo "  Porta SSH:  8022"
echo "  Utente:     $(whoami)"
echo ""

# Mostra IP del telefono
IP=$(ifconfig 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
if [ -z "$IP" ]; then
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
echo "  IP Telefono: $IP"
echo ""
echo "  Dal PC Windows lancia:"
echo "    .\invia-a-termux.ps1 -IP $IP"
echo ""
echo "  Oppure manualmente:"
echo "    scp -P 8022 -r phone-server/* $(whoami)@$IP:~/phone-server/"
echo ""
