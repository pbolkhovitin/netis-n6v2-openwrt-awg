# 09 — LuCI: протокол AmneziaWG и тема Proton2025

## Протокол `luci-proto-amneziawg`

### Симптом
В LuCI у интерфейса `awg0`: **«Unsupported protocol type. Install protocol extensions...»**,
хотя netifd-протокол работает и туннель поднят (`awg show awg0` показывает handshake).

### Причина
`amneziawg-tools` устанавливает только netifd-протокол `/lib/netifd/proto/amneziawg.sh`.
Для управления из веба нужен отдельный LuCI-пакет **`luci-proto-amneziawg`**, которого нет
в официальном репозитории OpenWrt.

### Где взять
В релизах `Slava-Shchipunov/awg-openwrt` пакет собирается **пер-таргет** (архитектура `all`,
но имя файла содержит target):

```
luci-proto-amneziawg_v25.12.6_aarch64_cortex-a53_mediatek_filogic.apk
```

Релиза под `SNAPSHOT` нет — берём ближайший 25.12.x (проверено на **25.12.6**).

### Установка
```sh
# Зависимости (resolveip обязателен, остальное обычно уже есть)
apk update && apk add resolveip

# Скачать ассет нужной версии/таргета
V=25.12.6
wget -qO /tmp/luci-proto-amneziawg.apk \
  https://github.com/Slava-Shchipunov/awg-openwrt/releases/download/v${V}/luci-proto-amneziawg_v${V}_aarch64_cortex-a53_mediatek_filogic.apk

# Пакет не подписан фидом OpenWrt
apk add --allow-untrusted /tmp/luci-proto-amneziawg.apk

# Сбросить кэш LuCI и перезапустить rpcd
rm -rf /tmp/luci-* /tmp/luci-indexcache*
/etc/init.d/rpcd restart
```

### Проверка
```sh
ubus list | grep amneziawg          # -> luci.amneziawg
curl -s -o /dev/null -w '%{http_code}\n' \
  http://127.0.0.1/luci-static/resources/protocol/amneziawg.js   # 200
```
В браузере — **жёсткое обновление** `Ctrl+Shift+R` (иначе остаётся старый кэш JS).

Зависимости пакета: `luci-base`, `luci-mod-network`, `luci-lib-uqr`, `ucode`, `resolveip`,
`amneziawg-tools`.

> ⚠️ У нас `luci-base` из snapshot (`26.x`), а протокол собран под 25.12.6. Обычно работает;
> если поля не отрисовываются — смотрите консоль браузера (F12) и при необходимости соберите
> `luci-proto-amneziawg` под текущий snapshot.

## Тема Proton2025

```sh
wget -qO- https://raw.githubusercontent.com/ChesterGoodiny/luci-theme-proton2025/main/install.sh \
  | WITH_DASHBOARD=1 sh
```

Скрипт ставит только пакет темы (`luci-theme-proton2025`, `.apk` через
`apk add --allow-untrusted`) и переключает `luci.main.mediaurlbase`.

### Проверка
```sh
uci get luci.main.mediaurlbase      # /luci-static/proton2025
curl -s -o /dev/null -w '%{http_code}\n' \
  http://192.168.1.1/luci-static/proton2025/css/cascade.css    # 200
```

### Откат на стандартную тему
```sh
uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci
/etc/init.d/uhttpd reload
```

> `WITH_DASHBOARD=1` пока ничего дополнительно не ставит: пакет
> `luci-app-proton2025-dashboard` не опубликован. Скрипт сам об этом предупреждает.

## Пакеты LuCI на роутере (факт)

| Пакет | Версия |
|---|---|
| `luci-base` | `26.285.40306~d12d553` (snapshot) |
| `luci-ssl` | установлен (HTTP/HTTPS на `192.168.1.1`) |
| `luci-proto-amneziawg` | `3.1.0-r1` |
| `resolveip` | `2` |
| `luci-theme-proton2025` | `1.4.4-r1` |
