# 07 — Состояние развёртывания и runbook

Снимок на **2026-10-14**.

## Что развёрнуто

| Компонент | Значение |
|---|---|
| Устройство | Netis N6 V2 (`netis,n6-v2`), aarch64 |
| Прошивка | OpenWrt SNAPSHOT `r37278-7af0c0f531`, ядро `6.18.55` |
| Пакетная система | `apk` |
| LuCI | `luci-ssl` установлен, HTTP/HTTPS на `192.168.1.1` (логин `root`) |
| Wi-Fi | `phy0-ap0` (2.4 ГГц, канал 1) и `phy1-ap0` (5 ГГц, канал 36), SSID `OpenWrt` |
| VPN-клиент | `kmod-amneziawg` (сборка под ядро) + `amneziawg-tools` |
| `awg0` | proto `amneziawg`, `10.8.1.7/32`, прослушивает локальный порт |
| Podkop | `connection_type=vpn` → `awg0`, `list community_lists 'russia_inside'` |
| Uplink | **отсутствует** (нет кабеля провайдера). Временный WiFi-STA свёрнут |

## Схема

```
LAN (br-lan 192.168.1.1) ──► PodkopTable (nft) ──► tproxy 127.0.0.1:1602
                                                       │ sing-box
                                                       ├─ main-out (bind_interface awg0) ──► VPN
                                                       └─ direct-out ──► WAN (провайдер)
```

Подробности маршрутизации — `docs/06-troubleshooting.md`, раздел «Как Podkop маршрутизирует».

## Runbook: подключили кабель провайдера в WAN

1. **WAN поднимется сам** (интерфейс `wan`, DHCP) — проверьте адрес и интернет:
   ```sh
   ifstatus wan | grep -E '"up"|"address"'
   ping -c3 8.8.8.8
   ```
2. **Уберите `nohostroute`** (был нужен для временного аплинка):
   ```sh
   uci set network.awg0.nohostroute='0'; uci commit network; ifup awg0
   ```
3. **Проверьте туннель** (см. `scripts/verify-tunnel.sh`):
   ```sh
   awg show awg0                                       # handshake, transfer ≠ 0
   curl -s --interface awg0 https://api.ipify.org      # IP VPN-сервера
   ```
4. **Проверьте Podkop**:
   ```sh
   podkop get_status                                   # {"enabled":1,"status":"enabled"}
   jq '.route.rule_set' /etc/sing-box/config.json      # НЕ пусто
   podkop restart
   ```
5. **Сквозной тест с клиента** (клиент должен реально ходить через роутер):
   ```sh
   nslookup www.youtube.com 192.168.1.1                # -> 198.18.x.x (fakeip)
   curl -s -o /dev/null -w '%{http_code}\n' https://www.youtube.com   # 200
   ```

## Техническое обслуживание

- **Список доменов** обновляется автоматически (cron `13 9 * * * /usr/bin/podkop list_update`).
  Вручную: `podkop list_update`.
- **Обновление snapshot**: `sysupgrade` не сохраняет пакеты — держите артефакты сборки
  (`kmod-amneziawg`, `amneziawg-tools`) и ставьте заново; либо не обновляйте snapshot без нужды.
- **Резервная копия конфигов**: `/etc/config/{network,wireless,podkop,firewall}` —
  не содержат секретов, кроме `network.awg0.private_key`/`preshared_key` (эти — только в Vault).

## Открытые вопросы

- Ротация утёкших секретов (клиентский приватный ключ; серверный — не трогать) — см. `docs/05-secrets.md`.
- Каталог с дампами заводского флеша хранить в надёжном месте (не в этом репозитории).
