# 03 — Podkop + sing-box

## Что такое Podkop

[Podkop](https://github.com/itdoginfo/podkop) — селективный прокси-роутинг на базе
**sing-box** для OpenWrt (нужен OpenWrt ≥ 24.10 и ≥ 25 МБ флеша). Позволяет направлять
через VPN только определённые домены/IP (списки сообщества, свои списки), остальное — напрямую.

## Установка

```sh
# На роутере (нужен интернет!)
wget -qO /tmp/podkop-install.sh \
  https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh
echo y | sh /tmp/podkop-install.sh
```

Ставит: `podkop`, `luci-app-podkop`, `luci-i18n-podkop-ru`, `sing-box` и зависимости
(`kmod-nf-tproxy`, `kmod-nft-tproxy`, `kmod-tun`, `kmod-inet-diag`, `curl`, `jq`, `bind-dig` и др.).

CLI: `/usr/bin/podkop` (`start|stop|reload|restart|get_status|check_proxy|check_sing_box|show_config`).
GUI: **LuCI → Services → Podkop**.

## Тип подключения

Podkop поддерживает в `proxy_string` протоколы: **vless, ss (Shadowsocks), trojan,
hysteria2, socks4/4a/5** — либо HTTPS-подписку, либо ручные параметры. Формат `vpn://`
(AmneziaVPN) **не поддерживается**.

Для AmneziaWG используется режим **`connection_type 'vpn'`** с указанием готового
интерфейса (`awg0`), который создаётся netifd (см. `02-amneziawg.md`).

## Схема

```
LAN (br-lan) ──► nftables (Podkop) ──┬─► awg0 (AmneziaWG) ──► VPN-сервер
                                     └─► WAN (напрямую)
```

## Пример UCI

См. `configs/podkop-uci.example`. Ключевые поля:

- `settings.dns_type`, `settings.dns_server`, `settings.bootstrap` — DNS.
- `settings.source_network_interfaces` — LAN-интерфейс (обычно `br-lan`).
- `settings.config_path` — путь к `sing-box` config (генерит Podkop).
- `main.connection_type 'vpn'`, `main.interface 'awg0'`.
- `main.community_lists` — списки доменов (напр. `russia_inside`, `russia_outside`, `geoblock`).

## ⚠️ `community_lists` — это UCI-список (`list`), не скаляр (`option`)

Если список задан скаляром, Podkop **молча ничего не маршрутизирует**: в логе будет
«Processing community list routing rules», но sing-box-конфиг останется без ruleset.

Причина: в `/lib/functions.sh` этой сборки `config_list_foreach()` итерируется по
`<option>_LENGTH` / `<option>_ITEMn`, которые UCI создаёт для `list`, но не для `option`.

```sh
# НЕВЕРНО (скаляр) — именно так задаёт установщик по умолчанию:
uci set podkop.main.community_lists='russia_inside'

# ВЕРНО (список):
uci -q delete podkop.main.community_lists
uci add_list podkop.main.community_lists='russia_inside'
uci commit podkop && podkop restart
```

Проверка: `jq '.route.rule_set' /etc/sing-box/config.json` → должен появиться remote ruleset.

## Интернет роутеру при пустом WAN (временно)

Пока провайдер не подключён, интернет роутеру можно дать через PC (NAT):

```sh
# На PC (Linux):
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o <uplink> -j MASQUERADE

# На роутере:
ip route add default via <IP_PC> dev br-lan
echo nameserver 8.8.8.8 > /etc/resolv.conf
```

> ⚠️ Это **временная** схема. Убирайте после подключения провайдера:
> `sudo sysctl -w net.ipv4.ip_forward=0`; `sudo iptables -t nat -D POSTROUTING -o <uplink> -j MASQUERADE`.

## Проверка

```sh
podkop get_status                 # {"enabled":1,"status":"enabled"}
podkop check_sing_box             # installed/version_ok/service_exist = 1
jq '.route.rule_set' /etc/sing-box/config.json     # НЕ пуст при заданных community_lists
nft list table inet PodkopTable   # регистр важен; set podkop_subnets + chains mangle/proxy
ip rule | grep podkop             # 105: fwmark 0x100000 -> table podkop
```

С клиента (должен ходить через роутер):

```sh
nslookup www.youtube.com 192.168.1.1   # -> 198.18.x.x (fakeip), если домен в списке
curl -s https://api.ipify.org           # -> IP VPN-сервера (для доменов из списка)
```

> Полная карта проверок и грабли — `docs/06-troubleshooting.md`.
