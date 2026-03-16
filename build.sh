#!/usr/bin/env bash
# ClariceOS build script
# Sets up Chaotic-AUR on the host then runs mkarchiso

set -euo pipefail

WORK_DIR="${1:-/tmp/clariceos-work}"
OUT_DIR="${2:-/tmp/clariceos-out}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root (sudo $0)" >&2
  exit 1
fi

echo "==> Setting up Chaotic-AUR on host..."

# Install chaotic-aur keyring on host if not already present
if ! pacman-key --list-keys 3056513887B78AEB &>/dev/null; then
  pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  pacman-key --lsign-key 3056513887B78AEB
  pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' \
    || true
fi

# Ensure the mirrorlist exists on the host (fallback if package install failed)
if [[ ! -f /etc/pacman.d/chaotic-mirrorlist ]]; then
  echo "==> Creating fallback chaotic-mirrorlist on host..."
  cp "$SCRIPT_DIR/releng/airootfs/etc/pacman.d/chaotic-mirrorlist" \
     /etc/pacman.d/chaotic-mirrorlist
fi

echo "==> Cleaning previous work directory..."
rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR"

echo "==> Running mkarchiso..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$SCRIPT_DIR/releng/"

echo ""
echo "==> Build complete! ISO is in: $OUT_DIR"
ls -lh "$OUT_DIR"/*.iso 2>/dev/null || true
