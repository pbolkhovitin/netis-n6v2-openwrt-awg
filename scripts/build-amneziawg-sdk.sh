#!/usr/bin/env bash
# build-amneziawg-sdk.sh — сборка пакетов AmneziaWG (kmod + tools) в OpenWrt SDK
# под конкретное ядро snapshot. Запускать на x86_64 Linux (Fedora/Debian).
set -euo pipefail

TARGET="mediatek/filogic"
SDK_URL="https://downloads.openwrt.org/snapshots/targets/${TARGET}/openwrt-sdk-${TARGET//\//-}_gcc-14.4.0_musl.Linux-x86_64.tar.zst"
AWG_REPO="https://github.com/Slava-Shchipunov/awg-openwrt.git"
WORKDIR="${WORKDIR:-$PWD/awg-build}"

echo "==> Host-зависимости (Fedora): sudo dnf install -y gcc-c++ perl-IPC-Cmd perl-FindBin"

mkdir -p "$WORKDIR" && cd "$WORKDIR"

echo "==> 1. SDK"
if [ ! -d sdk ]; then
  mkdir -p sdk && cd sdk
  wget -q -c -O openwrt-sdk.tar.zst "$SDK_URL"
  tar --zstd -xf openwrt-sdk.tar.zst
  cd ..
fi
SDK_DIR="$(find "$WORKDIR/sdk" -maxdepth 1 -type d -name 'openwrt-sdk-*' | head -1)"

echo "==> 2. Пакеты AmneziaWG"
[ -d awg-openwrt ] || git clone --depth 1 "$AWG_REPO" awg-openwrt
cp -r awg-openwrt/kmod-amneziawg  "$SDK_DIR/package/" 2>/dev/null || true
cp -r awg-openwrt/amneziawg-tools "$SDK_DIR/package/" 2>/dev/null || true

echo "==> 3. Сборка"
cd "$SDK_DIR"
make defconfig
make package/kmod-amneziawg/compile  V=s
make package/amneziawg-tools/compile V=s

echo "==> 4. Артефакты"
find bin -iname "*amneziawg*"
echo
echo "Проверьте, что ревизия ядра SDK совпадает с роутером (uname -r / /etc/openwrt_release)."
