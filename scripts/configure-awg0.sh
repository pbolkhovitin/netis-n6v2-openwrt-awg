#!/usr/bin/env bash
# configure-awg0.sh — создать UCI-интерфейс awg0 (proto amneziawg) на роутере
# из клиентского AmneziaWG-конфига (native format).
#
# Использование:
#   ./configure-awg0.sh /path/to/client.conf [router]
#
# ВАЖНО: client.conf содержит секреты (PrivateKey, PresharedKey) — не коммитьте его.
# Владелец UCI-значений — сам роутер (/etc/config/network, права root).
set -euo pipefail

CONF="${1:?usage: $0 <client.conf> [router]}"
ROUTER="${2:-root@192.168.1.1}"
IFACE="awg0"

get() { awk -F'= *' -v k="$1" 'tolower($1) ~ k {gsub(/ /,"",$2); print $2; exit}' "$CONF"; }

PRIV=$(get '^privatekey')
ADDR=$(get '^address')
MTU=$(get '^mtu')
JC=$(get '^jc'); JMIN=$(get '^jmin'); JMAX=$(get '^jmax')
S1=$(get '^s1'); S2=$(get '^s2')
H1=$(get '^h1'); H2=$(get '^h2'); H3=$(get '^h3'); H4=$(get '^h4')
PUB=$(get '^publickey')
PSK=$(get '^presharedkey')
EP=$(get '^endpoint')
KEEP=$(get '^persistentkeepalive')
EPHOST="${EP%%:*}"; EPPORT="${EP##*:}"

echo "==> Настройка $IFACE на $ROUTER"
ssh "$ROUTER" sh -s <<EOF
set -e
# Интерфейс
uci -q delete network.$IFACE || true
uci set network.$IFACE=interface
uci set network.$IFACE.proto='amneziawg'
uci set network.$IFACE.private_key='$PRIV'
uci set network.$IFACE.addresses='$ADDR'
uci set network.$IFACE.mtu='$MTU'
uci set network.$IFACE.awg_jc='$JC'
uci set network.$IFACE.awg_jmin='$JMIN'
uci set network.$IFACE.awg_jmax='$JMAX'
uci set network.$IFACE.awg_s1='$S1'
uci set network.$IFACE.awg_s2='$S2'
uci set network.$IFACE.awg_h1='$H1'
uci set network.$IFACE.awg_h2='$H2'
uci set network.$IFACE.awg_h3='$H3'
uci set network.$IFACE.awg_h4='$H4'

# Peer (route_allowed_ips=0 — маршрутизацию делает Podkop)
while uci -q delete network.@amneziawg_${IFACE}[-1]; do :; done
uci add network amneziawg_${IFACE} >/dev/null
uci set network.@amneziawg_${IFACE}[-1].public_key='$PUB'
uci set network.@amneziawg_${IFACE}[-1].preshared_key='$PSK'
uci set network.@amneziawg_${IFACE}[-1].endpoint_host='$EPHOST'
uci set network.@amneziawg_${IFACE}[-1].endpoint_port='$EPPORT'
uci set network.@amneziawg_${IFACE}[-1].allowed_ips='0.0.0.0/0'
uci set network.@amneziawg_${IFACE}[-1].route_allowed_ips='0'
uci set network.@amneziawg_${IFACE}[-1].persistent_keepalive='$KEEP'
uci commit network
EOF

echo "==> Поднять интерфейс"
ssh "$ROUTER" "ifup $IFACE; sleep 2; ip addr show $IFACE 2>/dev/null | head -3; awg show 2>/dev/null | head"
echo "Готово. Проверьте handshake: ssh $ROUTER awg show"
