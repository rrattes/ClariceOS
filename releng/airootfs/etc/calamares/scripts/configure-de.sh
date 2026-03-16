#!/bin/bash
# ClariceOS — post-install desktop environment + theme configuration
# Runs inside the chroot of the newly installed system via Calamares shellprocess.

set -e

GNOME_INSTALLED=false
KDE_INSTALLED=false

pacman -Q gnome-shell    &>/dev/null 2>&1 && GNOME_INSTALLED=true
pacman -Q plasma-desktop &>/dev/null 2>&1 && KDE_INSTALLED=true

echo "ClariceOS: GNOME=$GNOME_INSTALLED  KDE=$KDE_INSTALLED"

# ── Display manager setup ─────────────────────────────────────────────────────
if $KDE_INSTALLED; then
    echo ">>> Configuring KDE Plasma + SDDM"

    systemctl enable  sddm.service 2>/dev/null || true
    systemctl disable gdm.service  2>/dev/null || true

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

    # Remove GNOME if present (user chose KDE exclusively)
    if $GNOME_INSTALLED; then
        echo ">>> Removing GNOME packages (user chose KDE)"
        pacman -Rns --noconfirm gnome gnome-extra gdm 2>/dev/null \
            || pacman -R --noconfirm gnome gdm 2>/dev/null \
            || true
    fi

elif $GNOME_INSTALLED; then
    echo ">>> Configuring GNOME + GDM"

    systemctl enable  gdm.service  2>/dev/null || true
    systemctl disable sddm.service 2>/dev/null || true

    # Remove AutomaticLogin=root that was set for the live session
    GDM_CONF="/etc/gdm/custom.conf"
    if [ -f "$GDM_CONF" ]; then
        sed -i 's/^AutomaticLoginEnable=True/AutomaticLoginEnable=False/' "$GDM_CONF"
        sed -i 's/^AutomaticLogin=root//' "$GDM_CONF"
        echo ">>> Fixed GDM autologin"
    fi

else
    echo "WARNING: No desktop environment detected. Skipping DM configuration."
fi

# ── Compile dconf database ────────────────────────────────────────────────────
if command -v dconf &>/dev/null; then
    dconf update 2>/dev/null && echo ">>> dconf database updated." || true
fi

# ── Apply Dracula theme to each new user ──────────────────────────────────────
# /etc/skel dotfiles were already copied by the Calamares users module.
# This block applies gsettings overrides for GNOME users so the theme
# is active on first login without requiring a dconf write by the user.
for home_dir in /home/*/; do
    [ -d "$home_dir" ] || continue
    username=$(basename "$home_dir")

    # GTK3
    mkdir -p "${home_dir}.config/gtk-3.0"
    [ -f "${home_dir}.config/gtk-3.0/settings.ini" ] || \
        cp /etc/skel/.config/gtk-3.0/settings.ini "${home_dir}.config/gtk-3.0/" 2>/dev/null || true

    # GTK4
    mkdir -p "${home_dir}.config/gtk-4.0"
    [ -f "${home_dir}.config/gtk-4.0/settings.ini" ] || \
        cp /etc/skel/.config/gtk-4.0/settings.ini "${home_dir}.config/gtk-4.0/" 2>/dev/null || true

    # KDE dotfiles (kdeglobals, plasmarc, kwinrc)
    if $KDE_INSTALLED; then
        for conf in kdeglobals plasmarc kwinrc; do
            [ -f "${home_dir}.config/${conf}" ] || \
                cp "/etc/skel/.config/${conf}" "${home_dir}.config/" 2>/dev/null || true
        done
    fi

    # Fix ownership
    chown -R "${username}:${username}" "${home_dir}.config/" 2>/dev/null || true
    echo ">>> Dracula theme applied for user: ${username}"
done

echo ">>> ClariceOS post-install configuration complete."
