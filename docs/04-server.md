# 04 — AmneziaWG-сервер (VDS)

## Обзор

VPN-сервер — Ubuntu VDS с AmneziaWG в Docker-контейнере **`amnezia-awg`**.

| Параметр | Значение |
|---|---|
| Хост | Ubuntu, ядро 5.15.x, x86_64 |
| Контейнер | `amnezia-awg` (образ `amnezia-awg`) |
| Транспорт | UDP `:44636` |
| Внутренняя сеть | `10.8.1.0/24` |
| Server pubkey | `<SERVER_PUBLIC_KEY>` |

> IP/hostname и доступы — в хранилище секретов (`05-secrets.md`), в репозиторий не коммитятся.

## Параметры обфускации (сервер)

```
Jc = 3   Jmin = 10   Jmax = 50
S1 = 106 S2 = 29
H1 = 69045419
H2 = 1818386959
H3 = 1918415293
H4 = 1111313905
```

Клиент должен использовать **те же** значения `Jc/Jmin/Jmax/S1/S2/H1..H4`.

## Данные внутри контейнера (`/opt/amnezia/awg/`)

- `wg0.conf` — конфигурация сервера (интерфейс, обфускация, пиры);
- `wireguard_psk.key` — общий preshared-ключ;
- `wireguard_server_private_key.key` / `wireguard_server_public_key.key`;
- `clientsTable` — таблица клиентов;
- инструмент `/usr/bin/wg` (вариант AmneziaWG).

## Добавление клиента (роутера)

1. Сгенерировать keypair (локально): `awg genkey` → приватный/публичный ключи.
2. На сервере добавить пир:
   ```sh
   wg set wg0 peer <CLIENT_PUBKEY> \
     preshared-key /opt/amnezia/awg/wireguard_psk.key \
     allowed-ips 10.8.1.7/32
   ```
3. Дописать блок `[Peer]` в `wg0.conf` (для персистентности):
   ```
   [Peer]
   PublicKey = <CLIENT_PUBKEY>
   PresharedKey = <PSK>
   AllowedIPs = 10.8.1.7/32
   ```

## Клиентский конфиг роутера (AmneziaWG native)

```
[Interface]
PrivateKey = <client-private-key>       # секрет
Address    = 10.8.1.7/32
MTU        = 1420
DNS        = 1.1.1.1
Jc = 3   Jmin = 10   Jmax = 50
S1 = 106 S2 = 29
H1 = 69045419  H2 = 1818386959  H3 = 1918415293  H4 = 1111313905

[Peer]
PublicKey           = <SERVER_PUBLIC_KEY>
PresharedKey        = <psk>             # секрет
Endpoint            = <server-ip>:44636
AllowedIPs          = 0.0.0.0/0
PersistentKeepalive = 25
```

Эти поля переносятся в UCI-интерфейс `awg0` (см. `configs/amneziawg-uci.example`).
