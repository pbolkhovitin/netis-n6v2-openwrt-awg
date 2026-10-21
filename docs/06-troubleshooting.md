# 06 — Диагностика и найденные грабли

Каждый пункт ниже — **подтверждённая** причина (воспроизведена и исправлена), а не гипотеза.

## Карта проверки (снизу вверх)

1. **Туннель**: `awg show awg0` → есть `latest handshake`, transfer ≠ 0.
2. **Egress туннеля**: `curl -s --interface awg0 https://api.ipify.org` → IP VPN-сервера.
3. **Конфиг Podkop**: `jq '.route.rule_set' /etc/sing-box/config.json` — **не пуст**.
4. **nft**: `nft list table inet PodkopTable` (регистр важен!) — set `podkop_subnets`, chains.
5. **DNS**: с клиента `nslookup <домен из списка> 192.168.1.1` → адрес из `198.18.0.0/15` (fakeip).
6. **Сквозной тест**: с клиента `curl https://<заблокированный сервис>` → `200`.

## AmneziaWG

### Сервер: литеральный `$PSK` в `wg0.conf` → туннель не поднимается
Симптом: у пира `rx = 0`, handshake нет; в контейнере нет процесса `wireguard-go` и нет
интерфейса `wg0`; ручной запуск даёт
`Key is not the correct length or format: '$PSK'` / `Configuration parsing error`.

Причина: в блоке `[Peer]` было записано `PresharedKey = $PSK` **без подстановки** реального ключа.
Фикс: подставить значение из `/opt/amnezia/awg/wireguard_psk.key`, затем
`docker exec amnezia-awg wg-quick up /opt/amnezia/awg/wg0.conf`.

> Урок: сервер (его контейнер) перечитывает `wg0.conf` при рестарте. Любая незавершённая правка
> файла мгновенно ломает туннель для всех клиентов.

### Версии AmneziaWG
AWG 3.1 (клиент) совместим с **классическим** форматом обфускации
(`Jc/Jmin/Jmax/S1/S2/H1..H4`). Несовместимость 1.0 ↔ 2.0/3.x касается **диапазонных** H1–H4 и
`S3/S4` — против 1.0-сервера их задавать нельзя. Если сервер — старая сборка (userspace
`wireguard-go` в контейнере `amnezia-awg`), держите `S3/S4/I1..I5/HeaderProtectionKey` выключенными.

### netifd: proto не зарегистрирован / setup аварийно завершается
- После установки `amneziawg-tools` протокол может быть ещё не виден (`proto: none`) —
  помогает `/etc/init.d/network restart`.
- Симптом: `ifup awg0` создаёт устройство, но netifd **сразу его удаляет**. Причина —
  `proto_add_host_dependency` для endpoint не находит маршрут (интернет идёт по маршруту,
  о котором netifd не знает: вручную добавленный `default` либо NAT с ПК). Фикс:
  `uci set network.awg0.nohostroute='1'; uci commit network` (при обычном WAN можно вернуть `0`).
- ⚠️ `network restart` сбрасывает вручную добавленные маршруты — восстанавливайте осознанно.

## Podkop

### `community_lists` должен быть UCI-списком (`list`), а не скаляром (`option`)
Симптом: `podkop get_status` = `enabled`, sing-box слушает `127.0.0.1:1602` и `127.0.0.42:53`,
но `jq '.route.rule_set'` **пуст**, в логе есть «Processing community list routing rules», а
трафик не маршрутизируется.

Причина: в `/lib/functions.sh` этой сборки `config_list_foreach()` итерируется по
`<option>_LENGTH` / `<option>_ITEMn`, которые UCI создаёт только для `list`. Для скалярного
`option community_lists '...'` длин нет → функция молча `return 0` → обработчик
`configure_community_list_handler` не вызывается.

Фикс:
```sh
uci -q delete podkop.main.community_lists
uci add_list podkop.main.community_lists='russia_inside'
uci commit podkop && podkop restart
```
Проверка: `jq '.route.rule_set' /etc/sing-box/config.json` → появляется remote ruleset (`.srs`).

### Как Podkop маршрутизирует (режим `vpn`)
1. DNS клиента → роутер (dnsmasq) → `127.0.0.42` (sing-box).
2. Для доменов из rule_set выдаётся **fakeip** из `198.18.0.0/15`.
3. Пакет на fakeip ловит nft (`PodkopTable`, chain `mangle`) → `meta mark 0x00100000`.
4. `ip rule` (105) → таблица `podkop` → `local default dev lo` → tproxy-сокет `127.0.0.1:1602`.
5. sing-box outbound `main-out` (`bind_interface: awg0`) → трафик в туннель.
   Прочее (не из списков) → реальный IP → `final: direct-out`.

### Проверка egress
```sh
curl -s --interface awg0 https://api.ipify.org   # IP VPN-сервера
curl -s https://api.ipify.org                     # IP провайдера (напрямую)
```
> Клиент должен реально ходить **через роутер** (`ip route`): если у него приоритетнее
> домашний default-маршрут, тест «через роутер» ничего не покажет.

### Прочее
- `/etc/init.d/podkop status` может показывать `not running`, хотя sing-box работает —
  оценивайте состояние по `podkop get_status` и живости процесса `sing-box`.
- Таблица nft называется **`PodkopTable`** (регистр!), таблица маршрутизации — `podkop`.
- `sing-box 1.14+`: предупреждения про устаревший `independent_cache` и implicit HTTP client
  для remote rule-set — безвредны.
- Каталог `/etc/podkop` может отсутствовать — списки хранятся как sing-box rule-set в
  `/tmp/sing-box/rulesets` (и в кэше sing-box), это нормально.

## LuCI

### «Unsupported protocol type» у интерфейса `awg0`
Симптом: в LuCI у `awg0` — «Unsupported protocol type. Install protocol extensions...», хотя
туннель работает. Причина: не установлен пакет **`luci-proto-amneziawg`** (`amneziawg-tools`
даёт только netifd-протокол). Установка (пер-таргетный `.apk` из релизов
`Slava-Shchipunov/awg-openwrt`) и проверка — `docs/09-luci.md`.

> После установки обязательны `rm -rf /tmp/luci-*`, `/etc/init.d/rpcd restart` и жёсткое
> обновление браузера (`Ctrl+Shift+R`), иначе ошибка остаётся из-за кэша JS.

