#!/bin/bash
# ClariceOS — Secure Boot setup via sbctl
# Runs inside the chroot of the newly installed system via Calamares shellprocess.
#
# This script PREPARES the system for Secure Boot enrollment.
# The user must complete enrollment after first boot (system cannot enroll
# keys while running from the installer chroot).
#
# sbctl workflow:
#   1. sbctl create-keys       — generate custom PK/KEK/db keys
#   2. sbctl enroll-keys -m    — enroll keys (with Microsoft keys for hardware compat)
#   3. sbctl sign -s <efi>     — sign EFI binaries
#   4. Reboot with Secure Boot enabled in firmware
#
# This script performs steps 1–3.  Step 4 (UEFI firmware) requires the user.

set -euo pipefail

# Only relevant on UEFI systems
if [ ! -d /sys/firmware/efi/efivars ]; then
    echo ">>> Secure Boot: not UEFI — skipping."
    exit 0
fi

# Require sbctl
if ! command -v sbctl &>/dev/null; then
    echo ">>> sbctl not found — Secure Boot setup skipped."
    echo "    Install sbctl after first boot: pacman -S sbctl"
    exit 0
fi

echo ">>> Configuring Secure Boot (sbctl)..."

# ── Generate keys ─────────────────────────────────────────────────────────────
if [ ! -f /usr/share/secureboot/keys/db/db.key ]; then
    sbctl create-keys \
        && echo "    Secure Boot keys created." \
        || { echo "    WARNING: sbctl create-keys failed."; exit 0; }
else
    echo "    Secure Boot keys already exist — skipping creation."
fi

# ── Enroll keys ───────────────────────────────────────────────────────────────
# -m includes Microsoft certificates (needed for signed drivers/hardware)
# Use --yes-this-might-brick-my-machine only in setup mode (efi vars writable)
if sbctl status 2>/dev/null | grep -q "Secure Boot.*disabled"; then
    sbctl enroll-keys -m 2>/dev/null \
        && echo "    Secure Boot keys enrolled (with Microsoft certs)." \
        || echo "    WARNING: key enrollment failed — may need to be done in firmware setup."
else
    echo "    Secure Boot already active or enrollment not possible from installer."
    echo "    Run 'sbctl enroll-keys -m' after first boot in Setup Mode."
fi

# ── Sign EFI binaries ─────────────────────────────────────────────────────────
ESP=$(findmnt -n -o TARGET /boot/efi 2>/dev/null || echo "/boot/efi")

sign_if_exists() {
    local path="$1"
    if [ -f "${path}" ]; then
        sbctl sign -s "${path}" 2>/dev/null \
            && echo "    Signed: ${path}" \
            || echo "    WARNING: could not sign ${path}"
    fi
}

# Sign Limine EFI binaries
sign_if_exists "${ESP}/EFI/limine/BOOTX64.EFI"
sign_if_exists "${ESP}/EFI/BOOT/BOOTX64.EFI"

# Sign kernels (sbctl -s saves them in the signature database for automatic re-signing)
sign_if_exists "/boot/vmlinuz-linux"
sign_if_exists "/boot/vmlinuz-linux-zen"

echo "    EFI binaries signed."
echo ""
echo ">>> Secure Boot preparation complete."
echo "    To finish Secure Boot enrollment:"
echo "    1. Reboot and enter UEFI firmware (usually DEL/F2 at startup)."
echo "    2. Enable 'Setup Mode' (or clear existing keys)."
echo "    3. Enable 'Secure Boot'."
echo "    4. Reboot — Secure Boot will use the ClariceOS keys."
echo "    Run 'sbctl status' after first boot to verify."
