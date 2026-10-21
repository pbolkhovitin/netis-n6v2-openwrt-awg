# Netis N6 V2 — OpenWrt + AmneziaWG + Podkop

Перевод роутера **Netis N6 V2** на **OpenWrt (snapshot)** с клиентом обфусцированного
VPN **AmneziaWG** (собственная сборка kernel-модуля под ядро роутера из OpenWrt SDK)
и селективной маршрутизацией через **Podkop** (sing-box).

> ⚠️ **Репозиторий приватный.** Секреты (приватные ключи, пароли, PSK) в него **не коммитятся** —
> только имена секретов и ссылки на хранилище. См. `docs/05-secrets.md`.

## Итоговое состояние

| Компонент | Значение |
|---|---|
| Устройство | Netis N6 V2 (`netis,n6-v2`) |
| Прошивка | OpenWrt SNAPSHOT `r37278-7af0c0f531` |
| Целевая платформа | `mediatek/filogic` (aarch64_cortex-a53) |
| Ядро | 6.18.55 |
| VPN-клиент | AmneziaWG (kmod-amneziawg, сборка под ядро) |
| Маршрутизация | Podkop + sing-box |
| Пакетная система | `apk` (OpenWrt 24.10+/snapshot) |

> ✅ **Проверено**: туннель поднят (handshake), egress через `awg0` = IP VPN-сервера,
> Podkop направляет домены из списков через туннель. Грабли и диагностика — `docs/06-troubleshooting.md`.

## Состояние развёртывания (2026-10-21)

| Что | Статус |
|---|---|
| Прошивка | OpenWrt SNAPSHOT `r37278-7af0c0f531`, ядро `6.18.55`, `netis,n6-v2` |
| Пароль root / LuCI | задан; `luci-ssl` установлен (HTTP/HTTPS на `192.168.1.1`) |
| LuCI-протокол AWG | `luci-proto-amneziawg 3.1.0-r1` + `resolveip` — `awg0` редактируется в вебе (`docs/09-luci.md`) |
| Тема LuCI | `luci-theme-proton2025 1.4.4-r1` (`mediaurlbase=/luci-static/proton2025`) |
| Wi-Fi | **AP**: `ComTex2` (2.4 ГГц) и `ComTex5` (5 ГГц), **WPA2 (CCMP)**; пароль временный — сменить |
| AmneziaWG | `kmod-amneziawg` + `amneziawg-tools` собраны и установлены; `awg0` (`10.8.1.7/32`) создаётся при живом аплинке |
| Podkop | `connection_type=vpn` → `awg0`, community-список `russia_inside` (задан как UCI-**`list`**) |
| Туннель | ✅ проверен через временный аплинк: handshake, egress `awg0` = IP VPN-сервера, YouTube → `200` |
| Провайдер (WAN) | ⏳ **кабеля нет** (`wan` carrier=0); WAN подготовлен под **PPPoE** (JustLan/Квант, Липецк, MTU 1492) — `docs/08-provider-quant.md` |

> Роутер сейчас **без интернета по объективной причине**: к WAN не подключён провайдер, а
> временный аплинк убран. Туннель и Podkop заработают автоматически, как только появится WAN.
> Порядок действий после подключения провайдера — `docs/07-status.md`.

## Аппаратные характеристики

| Параметр | Значение |
|---|---|
| SoC | MediaTek MT7981B (ARM Cortex-A53) |
| RAM | 256 MiB DDR3 |
| Flash | 128 MiB SPI-NAND |
| Ethernet | 4× GbE (MT7531 switch) |
| Wi-Fi | 2.4 GHz MT7981 + 5 GHz MT7976C (Wi-Fi 6) |
| USB | USB 3.0 |
| UART | 115200 8N1 |

## Почему не «просто прошивка»

Роутер **Netis N6 V2** (ARM, MT7981) аппаратно **несовместим** с Netis N6 **V1** (MIPS, MT7621).
Образ для V1 (`ramips/mt7621`, `factory.bin`) превратит V2 в кирпич. Поддержка N6 V2 существует
**только в snapshot OpenWrt** (`mediatek/filogic`), в релизах 25.12.x её нет.

Кроме того, в РФ обычный WireGuard блокируется DPI, поэтому используется **AmneziaWG**
(WireGuard с обфускацией). Официального пакета AmneziaWG для snapshot нет — модуль собирается
самостоятельно из исходников под конкретное ядро роутера (см. `docs/02-amneziawg.md`).

## Структура репозитория

```
.
├── README.md
├── docs/
│   ├── 00-hardware.md        # железо, разделы флеша, U-Boot
│   ├── 01-flashing.md        # выбор образа, TFTP-recovery, sysupgrade
│   ├── 02-amneziawg.md       # сборка kmod-amneziawg из OpenWrt SDK
│   ├── 03-podkop.md          # установка и настройка Podkop/sing-box
│   ├── 04-server.md          # AmneziaWG-сервер (VDS) — обзор
│   ├── 05-secrets.md         # работа с секретами (agent-vault)
│   ├── 06-troubleshooting.md # диагностика: найденные грабли и проверки
│   ├── 07-status.md          # состояние развёртывания и runbook
│   ├── 08-provider-quant.md  # подключение провайдера «Квант» (JustLan, PPPoE)
│   └── 09-luci.md            # LuCI: протокол amneziawg и тема Proton2025
├── scripts/
│   ├── build-amneziawg-sdk.sh   # сборка пакетов AmneziaWG в SDK
│   ├── tftp-recovery.sh         # TFTP-сервер для recovery роутера
│   ├── configure-awg0.sh        # настройка интерфейса awg0 (шаблон, без секретов)
│   └── verify-tunnel.sh         # проверка туннеля и Podkop на роутере
└── configs/
    ├── amneziawg-uci.example    # пример UCI-конфига awg0
    └── podkop-uci.example       # пример секции podkop
```

## Быстрый старт

1. **Прошивка** — `docs/01-flashing.md`
2. **Сборка AmneziaWG** — `docs/02-amneziawg.md`
3. **Настройка Podkop** — `docs/03-podkop.md`

## Предупреждения

- Snapshot-образы OpenWrt обновляются ежедневно, а `vermagic` ядра меняется → собранный
  kernel-модуль грузится **только** на точную версию ядра. Обновление прошивки = пересборка модуля.
- Перед прошивкой делайте дамп заводского флеша (BL2/`u-boot-env`/`Factory`/`FIP`) и храните его.
