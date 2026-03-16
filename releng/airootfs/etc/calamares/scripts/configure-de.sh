#!/bin/bash
# ClariceOS — post-install desktop environment configuration
# Runs inside the chroot of the newly installed system.
#
# Detects whether GNOME or KDE Plasma was installed and:
#  - Enables the correct display manager
#  - Removes the unchosen DE to save disk space
#  - Fixes GDM autologin (was set to root for the live session)

set -e

GNOME_INSTALLED=false
KDE_INSTALLED=false

pacman -Q gnome-shell   &>/dev/null 2>&1 && GNOME_INSTALLED=true
pacman -Q plasma-desktop &>/dev/null 2>&1 && KDE_INSTALLED=true

echo "ClariceOS DE configuration: GNOME=$GNOME_INSTALLED  KDE=$KDE_INSTALLED"

if $KDE_INSTALLED; then
    echo ">>> Configuring KDE Plasma + SDDM"

    # Enable SDDM, disable GDM
    systemctl enable  sddm.service 2>/dev/null || true
    systemctl disable gdm.service  2>/dev/null || true

    # Write a minimal SDDM configuration
    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/clariceos.conf << 'EOF'
[Autologin]
Relogin=false
Session=
User=

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
EOF

    # Remove GNOME if also present (user chose KDE exclusively)
    if $GNOME_INSTALLED; then
        echo ">>> Removing GNOME packages (user chose KDE)"
        pacman -Rns --noconfirm gnome gnome-extra gdm 2>/dev/null \
            || pacman -R --noconfirm gnome gdm 2>/dev/null \
            || true
    fi

elif $GNOME_INSTALLED; then
    echo ">>> Configuring GNOME + GDM"

    # Enable GDM, disable SDDM if somehow present
    systemctl enable  gdm.service  2>/dev/null || true
    systemctl disable sddm.service 2>/dev/null || true

    # Fix GDM config: remove AutomaticLogin that was set for the live session
    GDM_CONF="/etc/gdm/custom.conf"
    if [ -f "$GDM_CONF" ]; then
        sed -i 's/^AutomaticLoginEnable=True/AutomaticLoginEnable=False/' "$GDM_CONF"
        sed -i 's/^AutomaticLogin=root//' "$GDM_CONF"
        echo ">>> Fixed GDM autologin in $GDM_CONF"
    fi

else
    echo "WARNING: No desktop environment detected. Skipping DM configuration."
fi

echo ">>> Desktop environment configuration complete."
