# 01 — Прошивка: выбор образа, TFTP-recovery, sysupgrade

## 1. Выбор образа

Для Netis N6 V2 нужен **snapshot** OpenWrt, target `mediatek/filogic`:

```
https://downloads.openwrt.org/snapshots/targets/mediatek/filogic/
  openwrt-mediatek-filogic-netis_n6-v2-bl31-uboot.fip
  openwrt-mediatek-filogic-netis_n6-v2-initramfs-recovery.itb
  openwrt-mediatek-filogic-netis_n6-v2-squashfs-sysupgrade.itb
```

Проверка контрольных сумм — обязательно (`sha256sums` в том же каталоге).

> ⚠️ Snapshot обновляется ежедневно. Версия ядра (`vermagic`) меняется — kernel-модули,
> собранные под другой snapshot, не загрузятся. Фиксируйте версию ядра и держите артефакты.

## 2. Процедура установки (с официальной прошивки Netis)

Обобщённая официальная процедура:

1. Поднять **TFTP-сервер** на PC с адресом `192.168.1.254` (порт 69/udp), в каталоге которого
   лежат `initramfs-recovery.itb` и `bl31-uboot.fip`.
2. Зайти по SSH на роутер (`root@192.168.1.1`).
3. Записать новый U-Boot/ATF и стереть UBI:
   ```sh
   mtd write /tmp/bl31-uboot.fip FIP
   mtd erase ubi
   reboot
   ```
4. U-Boot после перезагрузки сам скачает `initramfs-recovery.itb` по TFTP и запустит recovery.
5. В recovery выполнить sysupgrade на постоянный образ:
   ```sh
   sysupgrade -n /tmp/sysupgrade.itb      # -n чтобы не тащить конфиг
   ```

### Нюансы

- `scp`/`sftp` на устройстве может отсутствовать → файлы заливать через `ssh 'cat > /tmp/x'`:
  ```sh
  cat bl31-uboot.fip | ssh root@192.168.1.1 'cat > /tmp/fip.bin'
  ```
- Обновление snapshot → snapshot (уже на OpenWrt): проще напрямую
  ```sh
  sysupgrade /tmp/sysupgrade.itb         # без -n: сохранить /etc/config
  ```
- При sysupgrade **пакеты не сохраняются** (только `/etc/config`) → podkop/sing-box/LuCI надо
  ставить заново (см. `03-podkop.md`).

## 3. Перед прошивкой

- Снять дамп заводского флеша (`docs/00-hardware.md`).
- Убедиться, что PC видит роутер: `ping 192.168.1.1`, SSH `root@192.168.1.1`.

## 4. После прошивки (snapshot)

```sh
# Пароль root (если пуст):
printf '<ROOT_PASSWORD>\n<ROOT_PASSWORD>\n' | passwd root

# Интернет роутеру (если WAN пуст, временно через PC — см. docs/03-podkop.md)
# LuCI + HTTPS:
apk update && apk add luci-ssl
/etc/init.d/uhttpd enable && /etc/init.d/uhttpd start

# Wi-Fi (по умолчанию выключен):
uci set wireless.radio0.disabled=0
uci set wireless.radio1.disabled=0
uci set wireless.default_radio0.disabled=0
uci set wireless.default_radio1.disabled=0
uci commit wireless && wifi reload
```

Веб-интерфейс: `http://192.168.1.1` и `https://192.168.1.1`, логин `root`.
