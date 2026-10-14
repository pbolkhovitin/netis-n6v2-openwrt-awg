#!/bin/sh
# Проверка туннеля AmneziaWG и Podkop на роутере.
# Запуск НА РОУТЕРЕ:  sh verify-tunnel.sh
# (или из PC: ssh root@192.168.1.1 'sh -s' < scripts/verify-tunnel.sh)
#
# Секреты не выводятся: awg show маскирует ключи, в конфиг Podkop не заглядываем.

set -u

echo "== 1. Интерфейс awg0 =="
if awg show awg0 >/dev/null 2>&1; then
    awg show awg0 transfer | sed 's/^/   /'
    awg show awg0 latest-handshakes | sed 's/^/   /'
else
    echo "   !! awg0 отсутствует (ifup awg0)"
fi

echo "== 2. Egress туннеля =="
vpn_ip="$(curl -s --max-time 10 --interface awg0 https://api.ipify.org 2>/dev/null)"
echo "   через awg0 : ${vpn_ip:-<нет ответа>}"
ext_ip="$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null)"
echo "   напрямую   : ${ext_ip:-<нет ответа>}"

echo "== 3. sing-box / Podkop =="
pgrep -f 'sing-box run' >/dev/null 2>&1 && echo "   sing-box: работает" || echo "   sing-box: НЕ найден"
echo "   rule_set : $(jq -c '.route.rule_set' /etc/sing-box/config.json 2>/dev/null)"
if command -v podkop >/dev/null 2>&1; then
    echo "   podkop   : $(podkop get_status 2>/dev/null)"
fi

echo "== 4. nft / ip rule (Podkop) =="
nft list table inet PodkopTable >/dev/null 2>&1 \
    && echo "   PodkopTable: есть (set podkop_subnets)" \
    || echo "   PodkopTable: НЕТ"
ip rule show | grep -q podkop && echo "   ip rule: podkop есть" || echo "   ip rule: podkop НЕТ"

echo "== 5. Локальная проверка DNS (fakeip) =="
echo "   nslookup www.youtube.com 127.0.0.1 -> ожидаем 198.18.0.0/15"
