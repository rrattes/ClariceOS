#!/bin/bash
# ClariceOS — mkinitcpio btrfs hook injector
# Runs inside the target system chroot via Calamares shellprocess.
# Adds the 'btrfs' hook to mkinitcpio.conf when root filesystem is btrfs,
# so the initramfs can mount btrfs subvolumes at boot.

set -euo pipefail

ROOT_FS=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "")

if [ "${ROOT_FS}" != "btrfs" ]; then
    echo "==> Root is not btrfs — skipping btrfs hook injection."
    exit 0
fi

echo "==> btrfs root detected — ensuring btrfs hook in mkinitcpio.conf..."

MKINITCPIO_CONF="/etc/mkinitcpio.conf"

if [ ! -f "${MKINITCPIO_CONF}" ]; then
    echo "    WARNING: ${MKINITCPIO_CONF} not found — skipping."
    exit 0
fi

# Check if btrfs hook is already present
if grep -qP '^HOOKS=.*\bbtrfs\b' "${MKINITCPIO_CONF}"; then
    echo "    btrfs hook already present — nothing to do."
    exit 0
fi

# Insert 'btrfs' before 'filesystems' in the HOOKS line
if grep -qP '^HOOKS=' "${MKINITCPIO_CONF}"; then
    sed -i 's/\(HOOKS=.*\)\bfilesystems\b/\1btrfs filesystems/' "${MKINITCPIO_CONF}"
    echo "    btrfs hook injected before filesystems."
else
    echo "    WARNING: HOOKS line not found in ${MKINITCPIO_CONF}."
    exit 1
fi

# Also ensure btrfs-progs is available (it should be via packages, but verify)
if ! command -v btrfs &>/dev/null; then
    echo "    WARNING: btrfs command not found — installing btrfs-progs..."
    pacman -S --noconfirm --needed btrfs-progs 2>/dev/null || true
fi

echo "==> btrfs hook injection complete."
