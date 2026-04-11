#!/bin/bash
# Pamac installation module

install_pamac() {
    echo ">>> Installing Pamac..."

    # First try the official repository package name (if available).
    if pacman -S --noconfirm --needed pamac 2>/dev/null; then
        echo "    Pamac installed from official repositories."

    # Otherwise, prefer Chaotic-AUR binary package (no source build).
    elif grep -q "chaotic-aur" /etc/pacman.conf 2>/dev/null; then
        pacman -S --noconfirm --needed pamac-aur 2>/dev/null \
            && echo "    Pamac (pamac-aur) installed from Chaotic-AUR." \
            || echo "    WARNING: Pamac package not found in Chaotic-AUR."

    # Last resort: build pamac-aur with yay.
    else
        BUILD_USER_PAMAC=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd 2>/dev/null || true)
        if [ -n "${BUILD_USER_PAMAC}" ] && command -v yay &>/dev/null; then
            echo "${BUILD_USER_PAMAC} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-pamac-install
            sudo -u "${BUILD_USER_PAMAC}" yay -S --noconfirm --needed pamac-aur 2>/dev/null \
                && echo "    Pamac (pamac-aur) installed via yay." \
                || echo "    WARNING: Pamac installation failed."
            rm -f /etc/sudoers.d/99-pamac-install
        else
            echo "    WARNING: Could not install Pamac (yay/user unavailable)."
        fi
    fi
}

