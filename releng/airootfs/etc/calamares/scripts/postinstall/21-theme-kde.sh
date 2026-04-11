#!/bin/bash
# KDE theme module (Layan-kde)

apply_kde_theme() {
    echo ">>> Installing Layan-kde theme..."
    LAYAN_KDE_URL="https://github.com/vinceliuice/Layan-kde/archive/refs/heads/main.tar.gz"
    if curl -fsSL -o /tmp/layan-kde.tar.gz "${LAYAN_KDE_URL}" 2>/dev/null; then
        mkdir -p /tmp/layan-kde-src
        tar -xzf /tmp/layan-kde.tar.gz -C /tmp/layan-kde-src --strip-components=1
        if [ -x /tmp/layan-kde-src/install.sh ]; then
            bash /tmp/layan-kde-src/install.sh 2>/dev/null || true
            echo "    Layan-kde installed."
        else
            echo "    WARNING: Layan-kde installer not found in archive."
        fi
        rm -rf /tmp/layan-kde-src /tmp/layan-kde.tar.gz
    else
        echo "    WARNING: Could not download Layan-kde (no internet?). Skipping."
    fi
}

