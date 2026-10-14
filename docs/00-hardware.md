# 00 — Железо, разделы флеша, U-Boot

## Платформа

| Параметр | Значение |
|---|---|
| Модель | Netis N6 V2 |
| Device (`board_name`) | `netis,n6-v2` |
| SoC | MediaTek MT7981B (ARM Cortex-A53, aarch64) |
| RAM | 256 MiB DDR3 |
| Flash | 128 MiB SPI-NAND |
| Ethernet | 4 порта 1 GbE через коммутатор MT7531 |
| Wi-Fi | MT7981 (2.4 GHz) + MT7976C (5 GHz), Wi-Fi 6 |
| USB | USB 3.0 |
| UART | 115200 8N1 |

## V1 против V2 — критично

| | Netis N6 **V1** | Netis N6 **V2** |
|---|---|---|
| SoC | MediaTek MT7621 (MIPS) | MediaTek MT7981B (ARM) |
| Архитектура | mips | aarch64 |
| OpenWrt target | `ramips/mt7621` | `mediatek/filogic` |
| Образ | `factory.bin` | `sysupgrade.itb` / `initramfs-recovery.itb` |
| Наличие в релизах | есть | только в **snapshot** |

Прошивка образа V1 на V2 = кирпич (несовпадение архитектуры). Проверить реальную модель:

```sh
cat /tmp/sysinfo/board_name          # netis,n6-v2 или mediatek,mt7981-...
cat /etc/config/upnpd | grep -i product
uname -m                             # aarch64  (у V1 было бы mips)
```

## Разделы флеша (заводское состояние, `mtd`)

| MTD | Смещение | Размер | Имя | Назначение |
|---|---|---|---|---|
| mtd0 | `08000000` | 128 MiB | `spi0.0` | весь чип |
| mtd1 | — | 1 MiB | `BL2` | Trusted Firmware BL2 |
| mtd2 | — | 512 KiB | `u-boot-env` | переменные U-Boot |
| mtd3 | — | 2 MiB | `Factory` | калибровки Wi-Fi / MAC |
| mtd4 | — | 2 MiB | `FIP` | Firmware Image Package (ATF + U-Boot) |
| mtd5 | — | ~114 MiB | `ubi` | прошивка + rootfs_data |

**Дамп заводского флеша обязателен** перед прошивкой. Сохраняем разделы (кроме `ubi`, он
покрыт `mtd0`):

```sh
for m in 0 1 2 3 4; do
  ssh root@192.168.1.1 "cat /dev/mtd${m}ro" > mtd${m}.bin
done
# проверка размеров:  mtd0=134217728  mtd1=1M  mtd2=512K  mtd3=2M  mtd4=2M
sha256sum mtd*.bin
```

## U-Boot (переменные окружения, `defenv`)

| Переменная | Значение |
|---|---|
| `ipaddr` | `192.168.1.1` |
| `serverip` | `192.168.1.254` |
| `loadaddr` | `0x46000000` |
| `bootconf` | `config-1` |
| `bootfile` | `openwrt-mediatek-filogic-netis_n6-v2-initramfs-recovery.itb` |
| `bootfile_fip` | `openwrt-mediatek-filogic-netis_n6-v2-bl31-uboot.fip` |
| `bootfile_upg` | `openwrt-mediatek-filogic-netis_n6-v2-squashfs-sysupgrade.itb` |

Логика загрузки: `bootcmd` → `boot_ubi` → `boot_production` (тома нет) → `boot_recovery` (тома нет)
→ `boot_tftp_forever` (бесконечный цикл TFTP-recovery). Восстановление: удерживать **reset**
при включении (`check_buttons` → `boot_tftp`).
