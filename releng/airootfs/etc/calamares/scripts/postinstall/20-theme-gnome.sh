#!/bin/bash
# GNOME theme module (Fluent)

apply_gnome_theme() {
    local gnome_theme="${1:-Fluent-Dark}"
    local cursor_theme="${2:-Adwaita}"

    echo ">>> Installing Fluent GTK theme..."
    FLUENT_URL="https://github.com/vinceliuice/Fluent-gtk-theme/archive/refs/heads/master.tar.gz"
    if curl -fsSL -o /tmp/fluent-gtk-theme.tar.gz "${FLUENT_URL}" 2>/dev/null; then
        mkdir -p /tmp/fluent-gtk-src
        tar -xzf /tmp/fluent-gtk-theme.tar.gz -C /tmp/fluent-gtk-src --strip-components=1
        if [ -x /tmp/fluent-gtk-src/install.sh ]; then
            bash /tmp/fluent-gtk-src/install.sh -d /usr/share/themes 2>/dev/null || true
            echo "    Fluent GTK theme installed."
        else
            echo "    WARNING: Fluent installer not found in archive."
        fi
        rm -rf /tmp/fluent-gtk-src /tmp/fluent-gtk-theme.tar.gz
    else
        echo "    WARNING: Could not download Fluent GTK theme (no internet?)."
    fi

    # Libadwaita consistency check: GTK4 assets must be present for the chosen theme.
    if [ -d "/usr/share/themes/${gnome_theme}/gtk-4.0" ]; then
        echo "    Libadwaita/GTK4 visual consistency check passed (${gnome_theme})."
    else
        echo "    WARNING: Theme '${gnome_theme}' missing gtk-4.0 assets; libadwaita apps may use defaults."
    fi

    mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
    cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

    cat > /etc/dconf/db/local.d/00-clariceos-theme << DCONF
[org/gnome/desktop/interface]
gtk-theme='${gnome_theme}'
icon-theme='Tela-dark'
cursor-theme='${cursor_theme}'
color-scheme='prefer-dark'
font-name='JetBrains Mono 11'
monospace-font-name='JetBrains Mono 11'
document-font-name='JetBrains Mono 11'

[org/gnome/desktop/wm/preferences]
theme='${gnome_theme}'
button-layout=':minimize,maximize,close'
titlebar-font='JetBrains Mono Bold 11'

[org/gnome/shell/extensions/user-theme]
name='${gnome_theme}'

[org/gnome/desktop/default-applications/terminal]
exec='kitty'
exec-arg=''
DCONF

    if command -v dconf &>/dev/null; then
        dconf update 2>/dev/null && echo ">>> dconf database updated." || true
    fi
}

