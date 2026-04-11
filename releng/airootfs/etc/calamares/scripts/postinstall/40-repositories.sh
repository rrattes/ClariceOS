#!/bin/bash
# Repository setup module (Chaotic-AUR)

setup_chaotic_aur() {
    echo ">>> Configuring Chaotic-AUR on installed system..."

    # Install keyring
    if curl -fsSL "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst" \
            -o /tmp/chaotic-keyring.pkg.tar.zst 2>/dev/null; then
        pacman-key --recv-key 3056513887B78AEB \
            --keyserver keyserver.ubuntu.com 2>/dev/null || true
        pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
        pacman -U --noconfirm /tmp/chaotic-keyring.pkg.tar.zst 2>/dev/null || true
        rm -f /tmp/chaotic-keyring.pkg.tar.zst
    else
        echo "    WARNING: Chaotic-AUR keyring unavailable (no internet?). Skipping."
        return 1
    fi

    # Install mirrorlist
    curl -fsSL "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst" \
        -o /tmp/chaotic-mirrorlist.pkg.tar.zst 2>/dev/null \
        && pacman -U --noconfirm /tmp/chaotic-mirrorlist.pkg.tar.zst 2>/dev/null || true
    rm -f /tmp/chaotic-mirrorlist.pkg.tar.zst

    # Add repo to pacman.conf if not already present
    if ! grep -q "chaotic-aur" /etc/pacman.conf; then
        cat >> /etc/pacman.conf << 'CHAOTIC_CONF'

# Chaotic-AUR — pre-compiled AUR packages
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
CHAOTIC_CONF
    fi

    pacman -Sy --noconfirm 2>/dev/null || true
    echo "    Chaotic-AUR configured."
}

