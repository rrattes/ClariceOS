#!/bin/bash
# Flatpak setup module

setup_flatpak_flathub() {
    echo ">>> Configuring Flatpak + Flathub..."
    if command -v flatpak &>/dev/null; then
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
            && echo "    Flathub remote added." \
            || echo "    WARNING: Flathub remote add failed (no internet?)."
    else
        echo "    WARNING: flatpak not found — skipping."
    fi
}

