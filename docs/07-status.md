# 07 — Состояние развёртывания и runbook

Снимок на **2026-10-21**.

## Что развёрнуто

| Компонент | Значение |
|---|---|
| Устройство | Netis N6 V2 (`netis,n6-v2`), aarch64 |
| Прошивка | OpenWrt SNAPSHOT `r37278-7af0c0f531`, ядро `6.18.55` |
| Пакетная система | `apk` |
| LuCI | `luci-ssl` установлен, HTTP/HTTPS на `192.168.1.1` (логин `root`) |
| LuCI-протокол AWG | `luci-proto-amneziawg 3.1.0-r1` + `resolveip` — в вебе `awg0` редактируется как AmneziaWG (см. `docs/09-luci.md`) |
| Тема LuCI | `luci-theme-proton2025 1.4.4-r1`, `luci.main.mediaurlbase=/luci-static/proton2025` |
| Wi-Fi | **AP**: `phy0-ap0` — `ComTex2` (2.4 ГГц, канал 1), `phy1-ap0` — `ComTex5` (5 ГГц, канал 36); **WPA2 (CCMP)**; пароль временный — сменить |
| VPN-клиент | `kmod-amneziawg` (сборка под ядро) + `amneziawg-tools` |
| `awg0` | proto `amneziawg`, `10.8.1.7/32`; **при отсутствии аплинка netifd устройство не создаёт** (`NO_DEVICE`) |
| Podkop | `connection_type=vpn` → `awg0`, `list community_lists 'russia_inside'`; стартует только при живом интернете (иначе `DNS check failed`) |
| Uplink (провайдер) | **кабеля нет** (`wan` carrier=0). WAN переведён в **PPPoE** (JustLan/Квант, Липецк, `mtu 1492`, `keepalive 10 60`), логин/пароль — плейсхолдеры; временный WiFi-STA (TECNO) и NAT с ПК свёрнуты |

## Схема

```
LAN (br-lan 192.168.1.1) ──► PodkopTable (nft) ──► tproxy 127.0.0.1:1602
                                                       │ sing-box
                                                       ├─ main-out (bind_interface awg0) ──► VPN
                                                       └─ direct-out ──► WAN (провайдер)
```

Подробности маршрутизации — `docs/06-troubleshooting.md`, раздел «Как Podkop маршрутизирует».

## Runbook: подключили кабель провайдера в WAN

> WAN уже переведён в **PPPoE** (детали — `docs/08-provider-quant.md`): остаётся вписать
> логин/пароль и зарегистрировать MAC у провайдера.

1. **Проверьте линк** (кабель именно в порту WAN):
   ```sh
   cat /sys/class/net/wan/carrier    # 1 = линк есть
   ```
   `0` → кабель не в том порту / нет линка от провайдера.
2. **Впишите логин/пароль PPPoE** (LuCI: Network → Interfaces → WAN, протокол PPPoE — либо UCI):
   ```sh
   uci set network.wan.username='<ЛОГИН>'; uci set network.wan.password='<ПАРОЛЬ>'
   uci commit network; /etc/init.d/network reload
   ifstatus wan | grep -E '"up"|"address"'    # должен быть получен IP
   ping -c3 8.8.8.8
   ```
   Не поднимается → MAC не зарегистрирован у провайдера (см. `docs/08-provider-quant.md`).
3. **`nohostroute`** уже выставлен в `0` (штатное значение при реальном WAN). Проверка:
   `uci get network.awg0.nohostroute` → `0`.
4. **Проверьте туннель** (см. `scripts/verify-tunnel.sh`):
   ```sh
   awg show awg0                                       # handshake, transfer ≠ 0
   curl -s --interface awg0 https://api.ipify.org      # IP VPN-сервера
   ```
5. **Проверьте Podkop** (после появления интернета он мог не стартовать — перезапустите):
   ```sh
   podkop get_status                                   # {"enabled":1,"status":"enabled"}
   jq '.route.rule_set' /etc/sing-box/config.json      # НЕ пусто
   podkop restart
   ```
6. **Сквозной тест с клиента** (клиент должен реально ходить через роутер):
   ```sh
   nslookup www.youtube.com 192.168.1.1                # -> 198.18.x.x (fakeip)
   curl -s -o /dev/null -w '%{http_code}\n' https://www.youtube.com   # 200
   ```

## Временный аплинк через WiFi-телефон (только для тестов)

Если нужен интернет до подключения провайдера (телефон раздаёт Wi-Fi):

```sh
# 1. STA на radio1 (5 ГГц), 5G-AP временно выключается
uci set wireless.wifinet3.disabled='1'
uci set wireless.wwan0='wifi-iface'
uci set wireless.wwan0.device='radio1'
uci set wireless.wwan0.mode='sta'
uci set wireless.wwan0.network='wwan'
uci set wireless.wwan0.ssid='<SSID телефона>'
uci set wireless.wwan0.encryption='psk2'
uci set wireless.wwan0.key='<ПАРОЛЬ>'
uci set network.wwan='interface'; uci set network.wwan.proto='dhcp'
uci add_list firewall.@zone[1].network='wwan'
uci commit wireless; uci commit network; uci commit firewall
wifi reload

# 2. Свёртывание обратно
uci -q delete wireless.wwan0; uci -q delete network.wwan
uci del_list firewall.@zone[1].network='wwan'
uci set wireless.wifinet3.disabled='0'
uci commit wireless; uci commit network; uci commit firewall
wifi reload
```

> Проверено: через такой uplink AWG и Podkop полностью работают (egress `awg0` = IP VPN-сервера,
> YouTube через туннель → `200`).

## Техническое обслуживание

- **Список доменов** обновляется автоматически (cron `13 9 * * * /usr/bin/podkop list_update`).
  Вручную: `podkop list_update`.
- **Обновление snapshot**: `sysupgrade` не сохраняет пакеты — держите артефакты сборки
  (`kmod-amneziawg`, `amneziawg-tools`) и ставьте заново; либо не обновляйте snapshot без нужды.
  После `sysupgrade` также переустанавливаются `luci-proto-amneziawg` и тема (`docs/09-luci.md`).
- **Резервная копия конфигов**: `/etc/config/{network,wireless,podkop,firewall}` —
  не содержат секретов, кроме `network.awg0.private_key`/`preshared_key` (эти — только в Vault).

## Открытые вопросы

- Ротация утёкших секретов (клиентский приватный ключ; серверный — не трогать) — см. `docs/05-secrets.md`.
- Пароли Wi-Fi/root временные — сменить после выдачи.
- Каталог с дампами заводского флеша хранить в надёжном месте (не в этом репозитории).
