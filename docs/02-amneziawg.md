# 02 — AmneziaWG: сборка kernel-модуля из OpenWrt SDK

## Зачем

AmneziaWG — это WireGuard с обфускацией (DPI-устойчивость). В официальном репозитории
OpenWrt пакета **нет**. Готовые сборки сообщества (`Slava-Shchipunov/awg-openwrt`) делаются
**только под релизы** OpenWrt (23.05.x / 24.10.x / 25.12.x). Наш роутер работает на
**snapshot** → пакетов под него нет, модуль надо собрать самому под точное ядро роутера.

## Ключевое ограничение: vermagic

Kernel-модуль грузится только на **точную** версию ядра. `vermagic` вида
`6.18.55-1-<hash>` зависит от версии ядра и хеша конфигурации ядра. Поэтому:

> Скачанный SDK должен быть **из того же билда snapshot**, что и прошивка на роутере.

Проверка соответствия:

```sh
# На роутере:
uname -r                 # 6.18.55
cat /etc/openwrt_release # DISTRIB_REVISION

# В SDK (feeds.conf.default): базовый коммит должен совпадать с ревизией прошивки
grep '^src-git --root=package base' feeds.conf.default
```

Если ревизии не совпадают — обновите роутер на тот snapshot, чей SDK вы используете
(`sysupgrade`), либо ищите SDK под свою ревизию.

## Зависимости сборки (host, Fedora)

```sh
sudo dnf install -y gcc-c++ perl-IPC-Cmd perl-FindBin
```

## Шаги

```sh
# 1. Скачать SDK нужного target
wget -q -c -O openwrt-sdk.tar.zst \
  https://downloads.openwrt.org/snapshots/targets/mediatek/filogic/openwrt-sdk-mediatek-filogic_gcc-14.4.0_musl.Linux-x86_64.tar.zst
tar --zstd -xf openwrt-sdk.tar.zst
cd openwrt-sdk-*/

# 2. Положить пакеты AmneziaWG (из репо awg-openwrt) в package/
git clone --depth 1 https://github.com/Slava-Shchipunov/awg-openwrt.git
cp -r awg-openwrt/kmod-amneziawg    package/
cp -r awg-openwrt/amneziawg-tools   package/

# 3. Собрать
make defconfig
make package/kmod-amneziawg/compile  V=s
make package/amneziawg-tools/compile V=s

# 4. Артефакты
find bin -iname "*amneziawg*"
```

Готовые пакеты (`.apk`): `kmod-amneziawg`, `amneziawg-tools`.

## Как устроен пакет

- `kmod-amneziawg/Makefile` — `KernelPackage/amneziawg`, исходник
  `github.com/amnezia-vpn/amneziawg-linux-kernel-module` (tag `v3.1.20260906`).
  `Build/Prepare` копирует `$(LINUX_DIR)/*` в `src/kernel/`; `Build/Compile` собирает
  out-of-tree модуль против дерева ядра SDK.
- `amneziawg-tools/Makefile` — ставит `awg` в `/usr/bin/awg`, netifd-протокол
  `amneziawg.sh` в `/lib/netifd/proto/` и watchdog `amneziawg_watchdog`.

## Установка на роутер

```sh
# Залить .apk на роутер (scp/sftp может отсутствовать)
cat kmod-amneziawg-*.apk | ssh root@192.168.1.1 'cat > /tmp/kmod-amneziawg.apk'
cat amneziawg-tools-*.apk | ssh root@192.168.1.1 'cat > /tmp/amneziawg-tools.apk'

apk add --allow-untrusted /tmp/kmod-amneziawg.apk /tmp/amneziawg-tools.apk
# проверка
lsmod | grep amneziawg
awg --version
```

## Конфигурация интерфейса (netifd, proto `amneziawg`)

UCI-опции интерфейса: `private_key`, `mtu`, `fwmark`, `awg_jc`, `awg_jmin`, `awg_jmax`,
`awg_s1`, `awg_s2`, `awg_s3`, `awg_s4`, `awg_h1`…`awg_h4`, `awg_i1`…`awg_i5`,
`awg_header_protection_key`, `awg_content_padding_addition` и др.
Peer (секция `amneziawg_<name>`): `public_key`, `preshared_key`, `allowed_ips`,
`route_allowed_ips`, `endpoint_host`, `endpoint_port`, `persistent_keepalive`.

Пример — `configs/amneziawg-uci.example`, скрипт — `scripts/configure-awg0.sh`.

> `route_allowed_ips=0` — маршрутизацию через туннель оставляем Podkop/sing-box,
> а не netifd (селективная маршрутизация).

## Подводные камни на роутере

### Регистрация netifd-протокола
После установки `amneziawg-tools` протокол `amneziawg` может быть ещё не зарегистрирован
(ubus показывал `proto: none`). Лечится `/etc/init.d/network restart`.

### `nohostroute=1`
Если интернет на роутере идёт по маршруту, о котором netifd не знает (вручную добавленный
`default` либо NAT с ПК), `proto_add_host_dependency` для endpoint возвращает ошибку, и netifd
**сразу удаляет** только что созданный интерфейс:

```sh
uci set network.awg0.nohostroute='1'
uci commit network      # при обычном WAN можно вернуть 0
```

### Проверка
```sh
awg show awg0                                       # handshake + параметры обфускации
curl -s --interface awg0 https://api.ipify.org      # должен вернуть IP VPN-сервера
```

## Совместимость с сервером

AmneziaWG 3.1 (клиент) обратно совместим с классическим форматом обфускации
(`Jc/Jmin/Jmax/S1/S2/H1..H4`), который задан на сервере. Новые параметры 3.x
(`S3/S4/I1..I5/HeaderProtectionKey`) должны оставаться **выключенными**, если сервер их не использует.
