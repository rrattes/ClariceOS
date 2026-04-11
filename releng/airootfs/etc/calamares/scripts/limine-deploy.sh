#!/bin/bash
# ClariceOS — Final Limine deploy (outside chroot)
set -euo pipefail

log()  { echo "==> [limine-deploy] $*"; }
warn() { echo "    WARNING: [limine-deploy] $*"; }
err()  { echo "ERROR: [limine-deploy] $*"; }

resolve_disk() {
    local src="$1"
    local parent=""
    while true; do
        parent=$(lsblk -no PKNAME "$src" 2>/dev/null | head -1 || true)
        [ -z "$parent" ] && break
        [ -b "/dev/${parent}" ] || break
        src="/dev/${parent}"
    done
    basename "$src"
}

find_target_root() {
    local candidates=("/tmp/calamares-root" "/mnt/install" "/mnt")
    for mp in "${candidates[@]}"; do
        if [ -f "${mp}/etc/os-release" ] && mountpoint -q "$mp" 2>/dev/null; then
            echo "$mp"
            return 0
        fi
    done
    return 1
}

detect_target_esp() {
    local target="$1"
    for rel in "boot/efi" "boot" "efi"; do
        local mp="${target}/${rel}"
        local fs
        fs=$(findmnt -n -o FSTYPE "$mp" 2>/dev/null || true)
        if mountpoint -q "$mp" 2>/dev/null && echo "$fs" | grep -qiE 'vfat|fat|msdos'; then
            echo "$mp"
            return 0
        fi
    done
    return 1
}

TARGET=$(find_target_root) || { err "Não foi possível localizar a raiz do sistema instalado."; exit 1; }
ROOT_DEVICE=$(findmnt -n -o SOURCE "$TARGET" 2>/dev/null || true)
[ -n "$ROOT_DEVICE" ] || { err "Não foi possível determinar ROOT_DEVICE para $TARGET"; exit 1; }

DISK=$(resolve_disk "$ROOT_DEVICE" || true)
[ -n "$DISK" ] && [ -b "/dev/${DISK}" ] || { err "Não foi possível resolver disco físico a partir de $ROOT_DEVICE"; exit 1; }

UEFI=false
[ -d /sys/firmware/efi/efivars ] && UEFI=true

ROOT_FS=$(findmnt -n -o FSTYPE "$TARGET" 2>/dev/null || echo unknown)
BTRFS=false
[ "$ROOT_FS" = "btrfs" ] && BTRFS=true

log "Target root: $TARGET"
log "Root device: $ROOT_DEVICE"
log "Target disk: /dev/$DISK"
log "UEFI=$UEFI btrfs=$BTRFS"

if ! $UEFI; then
    log "BIOS mode: installing Limine to MBR of /dev/$DISK"
    install -Dm644 /usr/share/limine/limine-bios.sys "$TARGET/boot/limine-bios.sys"
    limine bios-install "/dev/$DISK"
    sync
    log "Limine BIOS deploy concluído."
fi

if $UEFI; then
    ESP=$(detect_target_esp "$TARGET") || { err "UEFI detectado, mas ESP FAT não montada em $TARGET (boot/efi, boot ou efi)."; exit 1; }
    mkdir -p "$ESP/EFI/limine" "$ESP/EFI/BOOT"

    install -Dm644 /usr/share/limine/BOOTX64.EFI "$ESP/EFI/limine/BOOTX64.EFI"
    install -Dm644 /usr/share/limine/BOOTX64.EFI "$ESP/EFI/BOOT/BOOTX64.EFI"

    if [ -f "$TARGET/boot/limine.cfg" ]; then
        install -Dm644 "$TARGET/boot/limine.cfg" "$ESP/limine.cfg"
    fi

    if command -v efibootmgr >/dev/null 2>&1; then
        ESP_DEVICE=$(findmnt -n -o SOURCE "$ESP" 2>/dev/null || true)
        ESP_DISK=$(resolve_disk "$ESP_DEVICE" || true)
        ESP_PART=$(lsblk -no PARTN "$ESP_DEVICE" 2>/dev/null | head -1 || true)
        [ -z "$ESP_PART" ] && ESP_PART="1"

        if [ -n "$ESP_DISK" ] && [ -b "/dev/$ESP_DISK" ]; then
            efibootmgr --create --disk "/dev/$ESP_DISK" --part "$ESP_PART" \
                --label "ClariceOS (Limine)" --loader "\\EFI\\limine\\BOOTX64.EFI" \
                >/dev/null 2>&1 || warn "efibootmgr falhou; fallback EFI/BOOT será usado."
        else
            warn "Não foi possível resolver disco/partição da ESP para efibootmgr."
        fi
    fi

    sync
    log "Limine UEFI deploy concluído em $ESP"
fi

if $BTRFS; then
    if [ -f "$TARGET/usr/lib/systemd/system/limine-snapper-sync.path" ]; then
        systemctl --root="$TARGET" enable limine-snapper-sync.path >/dev/null 2>&1 || \
            warn "Falha ao habilitar limine-snapper-sync.path"
    fi
fi

log "Deploy final do Limine concluído."
