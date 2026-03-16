#!/bin/bash
# ClariceOS — Remove live-session-only packages from the installed system.
# Runs inside the target chroot via Calamares shellprocess.
#
# Replaces the built-in Calamares 'packages' module (pacman backend) which
# calls `pacman -Rs --noconfirm <all-at-once>` and fails the entire
# installation if any single package is not installed or has dependency
# conflicts.  This script removes each package individually, silently
# skipping ones that are absent, then cleans up orphans at the end.

set -uo pipefail

# Remove a package only if it is currently installed.
remove_if_present() {
    local pkg="$1"
    if pacman -Q "$pkg" &>/dev/null; then
        echo "  removing: $pkg"
        pacman -Rn --noconfirm "$pkg" 2>/dev/null || \
            echo "  WARNING: could not remove $pkg (dependency conflict) — skipping"
    fi
}

echo "==> ClariceOS: removing live-session packages..."

# ── Calamares installer ───────────────────────────────────────────────────────
for pkg in calamares calamares-libs python-pyqt5 python-yaml \
           python-jsonschema qt5-webengine qt5-svg ckbcomp hwinfo; do
    remove_if_present "$pkg"
done

# ── Arch install helpers ──────────────────────────────────────────────────────
for pkg in arch-install-scripts archinstall; do
    remove_if_present "$pkg"
done

# ── Live audio / boot helpers ─────────────────────────────────────────────────
for pkg in livecd-sounds mkinitcpio-archiso mkinitcpio-nfs-utils; do
    remove_if_present "$pkg"
done

# ── Live-only WiFi firmware builders ─────────────────────────────────────────
for pkg in b43-fwcutter broadcom-wl; do
    remove_if_present "$pkg"
done

# ── Rescue / recovery tools ───────────────────────────────────────────────────
for pkg in clonezilla ddrescue fsarchiver gpart partclone partimage testdisk; do
    remove_if_present "$pkg"
done

# ── Server / live-only services ───────────────────────────────────────────────
for pkg in cloud-init darkhttpd open-iscsi nbd; do
    remove_if_present "$pkg"
done

# ── Accessibility (live tty) ──────────────────────────────────────────────────
for pkg in espeakup brltty gpm; do
    remove_if_present "$pkg"
done

# ── Redundant bootloaders (ClariceOS uses Limine) ────────────────────────────
for pkg in grub refind syslinux; do
    remove_if_present "$pkg"
done

# ── Live-only build / filesystem tools ───────────────────────────────────────
for pkg in squashfs-tools; do
    remove_if_present "$pkg"
done

# ── Live-only zsh config ──────────────────────────────────────────────────────
for pkg in grml-zsh-config; do
    remove_if_present "$pkg"
done

# ── VM guest utilities ────────────────────────────────────────────────────────
for pkg in hyperv open-vm-tools qemu-guest-agent virtualbox-guest-utils-nox; do
    remove_if_present "$pkg"
done

# ── Legacy network dialers ────────────────────────────────────────────────────
for pkg in pptpclient rp-pppoe vpnc wvdial xl2tpd; do
    remove_if_present "$pkg"
done

# ── IRC client ────────────────────────────────────────────────────────────────
remove_if_present irssi

# ── alsa-utils: only remove if PipeWire/PulseAudio is present (keeps audio) ──
if pacman -Q pipewire-alsa &>/dev/null || pacman -Q pulseaudio-alsa &>/dev/null; then
    remove_if_present alsa-utils
else
    echo "  keeping alsa-utils (no pipewire-alsa/pulseaudio-alsa found)"
fi

# ── Orphan cleanup ────────────────────────────────────────────────────────────
echo "==> ClariceOS: cleaning up orphaned packages..."
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "${ORPHANS}" ]; then
    echo "${ORPHANS}" | while read -r pkg; do
        echo "  orphan: $pkg"
    done
    echo "${ORPHANS}" | pacman -Rn --noconfirm - 2>/dev/null \
        || echo "  WARNING: some orphans could not be removed"
else
    echo "  no orphans found."
fi

echo "==> ClariceOS: live-session package removal complete."
