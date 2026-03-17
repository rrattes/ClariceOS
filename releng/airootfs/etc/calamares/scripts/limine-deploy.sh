#!/bin/bash
# ClariceOS — Final Limine deploy
#
# Runs OUTSIDE the target chroot (dontChroot: true), as the very last step
# before Calamares unmounts the installed filesystems.
#
# Why outside the chroot?
#   The existing install-bootloader.sh generates limine.cfg inside the chroot
#   (correct, since paths are relative to the installed root). But
#   "limine bios-install /dev/sdX" writes to the raw MBR and depends on
#   /proc being fully functional inside the chroot — which Calamares does not
#   guarantee. Running this step outside the chroot uses the live ISO's
#   limine binary and has unconditional direct access to block devices.
#
# This script also enables limine-snapper-sync on btrfs installs via
# "systemctl --root" so no running systemd is needed.

set -euo pipefail

log()  { echo "==> [limine-deploy] $*"; }
warn() { echo "    WARNING: [limine-deploy] $*"; }

# ── Find the installed system's root mount point ──────────────────────────────
# Calamares mounts the target under /tmp/calamares-root by default.
# Fall back to scanning /proc/mounts for any non-root mount that looks like
# a Linux installation (has /etc/os-release).
find_target_root() {
    local candidates=("/tmp/calamares-root" "/mnt/install" "/mnt")
    for mp in "${candidates[@]}"; do
        if [ -f "${mp}/etc/os-release" ] && mountpoint -q "${mp}" 2>/dev/null; then
            echo "${mp}"
            return 0
        fi
    done

    # Fallback: scan mounts
    while IFS=" " read -r _ mp _; do
        [ "${mp}" = "/" ] && continue
        [ -f "${mp}/etc/os-release" ] || continue
        mountpoint -q "${mp}" 2>/dev/null || continue
        echo "${mp}"
        return 0
    done < /proc/mounts

    return 1
}

TARGET=$(find_target_root) || {
    log "ERROR: Cannot locate the installed system mount point."
    exit 1
}
log "Target root: ${TARGET}"

# ── Detect root device, UUID, and parent disk ─────────────────────────────────
ROOT_DEVICE=$(findmnt -n -o SOURCE "${TARGET}" 2>/dev/null)
ROOT_UUID=$(findmnt -n -o UUID "${TARGET}" 2>/dev/null)
DISK=$(lsblk -no PKNAME "${ROOT_DEVICE}" 2>/dev/null | head -1)

if [ -z "${ROOT_DEVICE}" ] || [ -z "${DISK}" ]; then
    log "ERROR: Cannot determine root device or parent disk."
    log "  ROOT_DEVICE='${ROOT_DEVICE}'  DISK='${DISK}'"
    exit 1
fi

log "Root device : ${ROOT_DEVICE}  (UUID=${ROOT_UUID})"
log "Parent disk : /dev/${DISK}"

# ── Detect UEFI and filesystem type ───────────────────────────────────────────
UEFI=false
[ -d /sys/firmware/efi/efivars ] && UEFI=true

ROOT_FS=$(findmnt -n -o FSTYPE "${TARGET}" 2>/dev/null || echo "unknown")
BTRFS=false
[ "${ROOT_FS}" = "btrfs" ] && BTRFS=true

log "UEFI=${UEFI}  btrfs=${BTRFS}"

# ── BIOS install ──────────────────────────────────────────────────────────────
if ! ${UEFI}; then
    log "BIOS mode — writing Limine bootstrap to MBR of /dev/${DISK}"

    # limine-bios.sys must be present on the installed /boot partition so the
    # bootstrap code can locate it at runtime (limine embeds its sector
    # address in the MBR stub during bios-install).
    BIOS_SYS="${TARGET}/boot/limine-bios.sys"
    if [ ! -f "${BIOS_SYS}" ]; then
        log "limine-bios.sys missing from target /boot — copying from live ISO."
        cp /usr/share/limine/limine-bios.sys "${BIOS_SYS}"
    else
        log "limine-bios.sys already present in target /boot — refreshing."
        cp /usr/share/limine/limine-bios.sys "${BIOS_SYS}"
    fi

    # Write Limine's boot code into the MBR.
    # We use the live ISO's limine binary (not the chrooted one) so we have
    # guaranteed direct access to the block device without chroot limitations.
    limine bios-install "/dev/${DISK}" \
        && log "Limine MBR written to /dev/${DISK} successfully." \
        || { log "ERROR: limine bios-install failed."; exit 1; }
fi

# ── UEFI install ──────────────────────────────────────────────────────────────
if ${UEFI}; then
    log "UEFI mode — ensuring EFI binaries and boot entry."

    # Detect ESP mount point inside the target
    ESP=""
    for try_rel in "boot/efi" "boot" "efi"; do
        try="${TARGET}/${try_rel}"
        if mountpoint -q "${try}" 2>/dev/null; then
            # Confirm it actually has an EFI directory or can host one
            ESP="${try}"
            break
        fi
    done
    [ -z "${ESP}" ] && ESP="${TARGET}/boot/efi"

    mkdir -p "${ESP}/EFI/limine" "${ESP}/EFI/BOOT"
    cp /usr/share/limine/BOOTX64.EFI "${ESP}/EFI/limine/"
    cp /usr/share/limine/BOOTX64.EFI "${ESP}/EFI/BOOT/"
    log "EFI binaries copied to ${ESP}."

    if command -v efibootmgr &>/dev/null; then
        ESP_DEVICE=$(findmnt -n -o SOURCE "${ESP}" 2>/dev/null | head -1 || echo "")
        if [ -n "${ESP_DEVICE}" ]; then
            EFI_PART_NUM=$(lsblk -no PARTN "${ESP_DEVICE}" 2>/dev/null | head -1 || echo "1")
            [ -z "${EFI_PART_NUM}" ] && EFI_PART_NUM="1"
            efibootmgr --create \
                --disk "/dev/${DISK}" \
                --part "${EFI_PART_NUM}" \
                --label "ClariceOS (Limine)" \
                --loader "/EFI/limine/BOOTX64.EFI" \
                2>/dev/null \
                && log "UEFI boot entry registered." \
                || warn "efibootmgr failed — EFI/BOOT fallback path will be used by firmware."
        else
            warn "Could not determine ESP device — skipping efibootmgr."
        fi
    fi
fi

# ── limine-snapper-sync (btrfs only) ─────────────────────────────────────────
if ${BTRFS}; then
    log "btrfs root detected — enabling limine-snapper-sync if installed."

    LSS_UNIT="${TARGET}/usr/lib/systemd/system/limine-snapper-sync.path"
    if [ -f "${LSS_UNIT}" ]; then
        # systemctl --root operates on the target without a running systemd
        systemctl --root="${TARGET}" enable limine-snapper-sync.path 2>/dev/null \
            && log "limine-snapper-sync.path enabled in installed system." \
            || warn "Failed to enable limine-snapper-sync.path."
    else
        log "limine-snapper-sync not found — skipping (install from AUR after first boot)."
    fi
fi

log "Limine deploy complete."
