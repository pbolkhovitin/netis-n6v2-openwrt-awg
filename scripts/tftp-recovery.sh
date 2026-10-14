#!/usr/bin/env bash
# tftp-recovery.sh — TFTP-сервер для recovery Netis N6 V2.
# Раскладывает initramfs-recovery.itb + bl31-uboot.fip в tftp-root и поднимает dnsmasq.
#
# Требует root (адрес 192.168.1.254 на интерфейсе + порт 69/udp).
set -euo pipefail

IFACE="${IFACE:-enp5s0}"
PC_IP="${PC_IP:-192.168.1.254}"
TFTP_ROOT="${TFTP_ROOT:-$PWD}"
LOG="${LOG:-/tmp/dnsmasq-tftp.log}"

echo "==> Адрес $PC_IP/24 на $IFACE"
sudo ip addr add "$PC_IP/24" dev "$IFACE" 2>/dev/null || echo "(адрес уже есть)"

echo "==> Открыть порт 69/udp в firewalld (если используется)"
sudo firewall-cmd --add-service=tftp >/dev/null 2>&1 || true

echo "==> Запуск TFTP"
sudo dnsmasq --conf-file=/dev/null --port=0 \
  --enable-tftp --tftp-root="$TFTP_ROOT" \
  --interface="$IFACE" --listen-address="$PC_IP" \
  --user=root --group=root --no-daemon \
  --log-facility="$LOG"

# Уборка после остановки (Ctrl-C):
#   sudo ip addr del $PC_IP/24 dev $IFACE
#   sudo firewall-cmd --remove-service=tftp
