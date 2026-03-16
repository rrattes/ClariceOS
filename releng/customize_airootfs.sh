#!/usr/bin/env bash
# ClariceOS — airootfs customization script
# Runs inside the airootfs chroot during `mkarchiso` build.
# Requires internet access at build time to download the Dracula GTK theme.

set -euo pipefail

echo "==> ClariceOS: applying Dracula theme..."

# ── Dracula GTK theme (GTK3 + GTK4) ─────────────────────────────────────────
# Download from the official Dracula GitHub releases.
DRACULA_GTK_URL="https://github.com/dracula/gtk/releases/download/v4.0/Dracula.tar.xz"
DRACULA_CURSOR_URL="https://github.com/dracula/gtk/releases/download/v4.0/Dracula-cursors.tar.xz"

mkdir -p /usr/share/themes

echo "--> Downloading Dracula GTK theme..."
if curl -fsSL -o /tmp/dracula-gtk.tar.xz "${DRACULA_GTK_URL}"; then
    tar -xJf /tmp/dracula-gtk.tar.xz -C /usr/share/themes/
    rm -f /tmp/dracula-gtk.tar.xz
    echo "    Dracula GTK theme installed."
else
    echo "    WARNING: Could not download Dracula GTK theme (no internet?). Skipping."
fi

echo "--> Downloading Dracula cursor theme..."
if curl -fsSL -o /tmp/dracula-cursors.tar.xz "${DRACULA_CURSOR_URL}"; then
    tar -xJf /tmp/dracula-cursors.tar.xz -C /usr/share/icons/
    rm -f /tmp/dracula-cursors.tar.xz
    # Build cursor theme cache
    for dir in /usr/share/icons/Dracula-cursors /usr/share/icons/Dracula; do
        [ -d "$dir" ] && gtk-update-icon-cache -f -t "$dir" 2>/dev/null || true
    done
    echo "    Dracula cursor theme installed."
else
    echo "    WARNING: Could not download Dracula cursor theme. Skipping."
fi

# ── KDE color scheme ─────────────────────────────────────────────────────────
# Written inline — no download required. Official Dracula palette.
mkdir -p /usr/share/color-schemes
cat > /usr/share/color-schemes/Dracula.colors << 'COLORS'
[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Complementary]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Selection]
BackgroundAlternate=68,71,90
BackgroundNormal=189,147,249
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=40,42,54
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=40,42,54
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Tooltip]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:View]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Window]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[General]
ColorScheme=Dracula
Name=Dracula
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=40,42,54
activeBlend=248,248,242
activeForeground=248,248,242
inactiveBackground=40,42,54
inactiveBlend=98,114,164
inactiveForeground=98,114,164
COLORS
echo "    Dracula KDE color scheme written."

# ── dconf GNOME system-wide defaults ─────────────────────────────────────────
mkdir -p /etc/dconf/db/local.d /etc/dconf/profile

cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

cat > /etc/dconf/db/local.d/00-clariceos-theme << 'DCONF'
[org/gnome/desktop/interface]
gtk-theme='Dracula'
icon-theme='Adwaita'
cursor-theme='Dracula-cursors'
color-scheme='prefer-dark'
font-name='Cantarell 11'

[org/gnome/desktop/wm/preferences]
theme='Dracula'
button-layout=':minimize,maximize,close'

[org/gnome/shell/extensions/user-theme]
name='Dracula'
DCONF

dconf update && echo "    dconf database compiled."

# ── GTK3 settings (root — live session) ──────────────────────────────────────
mkdir -p /root/.config/gtk-3.0 /root/.config/gtk-4.0
cat > /root/.config/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Dracula-cursors
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=true
GTK
cp /root/.config/gtk-3.0/settings.ini /root/.config/gtk-4.0/settings.ini

# ── /etc/skel dotfiles (copied to every new user by Calamares) ───────────────
mkdir -p /etc/skel/.config/gtk-3.0 /etc/skel/.config/gtk-4.0
cp /root/.config/gtk-3.0/settings.ini /etc/skel/.config/gtk-3.0/settings.ini
cp /root/.config/gtk-3.0/settings.ini /etc/skel/.config/gtk-4.0/settings.ini

# KDE dotfiles
mkdir -p /etc/skel/.config

cat > /etc/skel/.config/kdeglobals << 'KDEGLOBALS'
[General]
ColorScheme=Dracula
Name=Dracula
shadeSortColumn=true

[KDE]
ColorScheme=Dracula
contrast=4
widgetStyle=Breeze

[Icons]
Theme=breeze-dark

[Colors:Button]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Selection]
BackgroundAlternate=68,71,90
BackgroundNormal=189,147,249
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=40,42,54
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=40,42,54
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:View]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Window]
BackgroundAlternate=68,71,90
BackgroundNormal=40,42,54
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundActive=241,250,140
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[WM]
activeBackground=40,42,54
activeBlend=248,248,242
activeForeground=248,248,242
inactiveBackground=40,42,54
inactiveBlend=98,114,164
inactiveForeground=98,114,164
KDEGLOBALS

cat > /etc/skel/.config/plasmarc << 'PLASMARC'
[Theme]
name=breeze-dark
PLASMARC

cat > /etc/skel/.config/kwinrc << 'KWINRC'
[org.kde.kdecoration2]
library=org.kde.breeze
theme=__aurorae__svg__Dracula
KWINRC

cat > /etc/skel/.config/breezerc << 'BREEZERC'
[Common]
OutlineIntensity=OutlineOff
ShadowSize=ShadowVeryLarge

[Windeco]
ButtonSize=ButtonDefault
DrawBorderOnMaximizedWindows=false
BREEZERC

echo "    /etc/skel dotfiles written."

echo "==> ClariceOS: Dracula theme configuration complete."

# ── Chaotic-AUR setup (live ISO) ──────────────────────────────────────────────
# Adds the Chaotic-AUR repository so pre-compiled AUR packages are available
# in the live environment and in the installed system.
echo "==> ClariceOS: configuring Chaotic-AUR..."

if curl -fsSL "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst" \
        -o /tmp/chaotic-keyring.pkg.tar.zst 2>/dev/null; then
    pacman-key --recv-key 3056513887B78AEB \
        --keyserver keyserver.ubuntu.com 2>/dev/null || \
    pacman-key --recv-key 3056513887B78AEB \
        --keyserver hkps://keyserver.ubuntu.com 2>/dev/null || true
    pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
    pacman -U --noconfirm /tmp/chaotic-keyring.pkg.tar.zst 2>/dev/null || true
    rm -f /tmp/chaotic-keyring.pkg.tar.zst
    echo "    Chaotic-AUR keyring installed."
else
    echo "    WARNING: Could not download chaotic-keyring (no internet?). Skipping."
fi

if curl -fsSL "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst" \
        -o /tmp/chaotic-mirrorlist.pkg.tar.zst 2>/dev/null; then
    pacman -U --noconfirm /tmp/chaotic-mirrorlist.pkg.tar.zst 2>/dev/null || true
    rm -f /tmp/chaotic-mirrorlist.pkg.tar.zst
    echo "    Chaotic-AUR mirrorlist installed."
fi

# Sync chaotic-aur database (ignore errors if offline)
pacman -Sy --noconfirm 2>/dev/null || true

echo "==> ClariceOS: Chaotic-AUR configured."
