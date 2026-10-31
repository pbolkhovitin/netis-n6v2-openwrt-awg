# 08 — Подключение к провайдеру «Квант» (JustLan, &lt;город&gt;)

Провайдер: **АО «Квант‑Телеком»** (бренд **JustLan**, justlan.ru), `<город>`.
Тип подключения — **PPPoE**. Поддержка: **8‑800‑770‑01‑70**, **(473) 233‑01‑48**.

> Логин/пароль провайдера и пароли Wi‑Fi/root в репозиторий **не коммитятся** — только
> имена секретов в `docs/05-secrets.md`.

## Памятка при передаче абоненту (кратко)

1. Воткнуть кабель провайдера в порт **WAN** роутера.
2. Подключиться к Wi‑Fi **`OpenWrt`** (или по кабелю в LAN-порт).
3. Открыть LuCI → `http://192.168.1.1` (логин `root`).
4. **Сообщить MAC WAN роутера в поддержку JustLan** (8‑800‑770‑01‑70) — без регистрации MAC
   PPPoE-сессия не поднимется. Как узнать MAC — ниже.
5. LuCI → **Network → Interfaces → WAN** → ввести **логин/пароль PPPoE** из памятки
   провайдера → **Save & Apply**.
6. Проверить интернет; VPN (AmneziaWG + Podkop) поднимется автоматически.
7. **Сменить временные пароли** Wi‑Fi и `root`.

## Что уже настроено на роутере

| Параметр | Значение |
|---|---|
| WAN | протокол **PPPoE**, `mtu 1492`, `keepalive 10 60`, `service` пусто; логин/пароль — **плейсхолдеры** |
| WAN IPv6 | `wan6` через `@wan` (dhcpv6 поверх PPPoE) |
| Wi‑Fi | 2.4 ГГц (`<SSID_2G>`) + 5 ГГц (`<SSID_5G>`), **WPA2 (CCMP)**; временный пароль (сменить!) |
| VPN | `awg0` (AmneziaWG), `nohostroute=0`; Podkop → `awg0` |

## Что нужно от абонента (до подключения)

1. **Логин и пароль PPPoE** — из абонентской памятки/договора JustLan.
2. **Зарегистрировать MAC-адрес роутера в поддержке** — КРИТИЧНО.
   Провайдер пропускает в сеть только устройство с зарегистрированным MAC; иначе PPPoE-сессия
   не поднимется. Альтернатива — клонировать MAC старого рабочего устройства (см. ниже).
3. **Сменить временные пароли** Wi‑Fi и root после установки.

### MAC-адрес WAN роутера

```sh
# по SSH или через LuCI:
cat /sys/class/net/wan/address
```
Либо LuCI → Network → Interfaces → Devices → `wan` → «MAC address».
Этот адрес сообщить в поддержку JustLan.

## Порядок подключения

1. Воткнуть кабель провайдера в порт **WAN**.
2. LuCI (`http://192.168.1.1`, логин `root`) → **Network → Interfaces → WAN → Edit**:
   - Protocol: **PPPoE**
   - **PAP/CHAP username**: *логин из памятки*
   - **PAP/CHAP password**: *пароль из памятки*
   - Service name: **пусто**
   - Advanced Settings: **MTU 1492**, Keepalive `10 60`, «Use default gateway» ✓
   - **Save & Apply**.
3. Убедиться, что WAN получил IP (Overview / WAN → IPv4 up).

### Быстро через SSH (UCI)

```sh
uci set network.wan.username='<ЛОГИН>'
uci set network.wan.password='<ПАРОЛЬ>'
uci commit network
/etc/init.d/network reload
```

### MAC-клонирование (если провайдер привязан к MAC старого устройства)

```sh
uci set network.wan.macaddr='AA:BB:CC:DD:EE:FF'
uci commit network
/etc/init.d/network reload
```

## После появления интернета — проверить VPN

```sh
sh /root/verify-tunnel.sh       # копия scripts/verify-tunnel.sh
/usr/bin/podkop restart
```
E2E: с Wi‑Fi-клиента открыть youtube.com — должен получить fakeip `198.18.x` и открыться через туннель.

## Частые проблемы

| Симптом | Причина / решение |
|---|---|
| PPPoE не поднимается («no response») | MAC не зарегистрирован у провайдера → обратиться в поддержку; либо MAC-клонирование |
| «Authentication failed» | проверить логин/пароль; провайдер использует CHAP (по умолчанию у pppd) |
| Сайты грузятся частично, «рвётся» TLS | MTU 1492 (PPPoE) + MSS-clamping (у зоны WAN `mtu_fix=1`) |
| Нет IPv6 | `wan6` = `@wan`; при отсутствии IPv6 у провайдера — не критично |

## Смена временных паролей (обязательно)

```sh
passwd root          # пароль root (он же для LuCI)
```
Wi‑Fi: LuCI → **Network → Wireless** → *Edit* нужной сети → **Wireless Security** → WPA2, новый пароль.
