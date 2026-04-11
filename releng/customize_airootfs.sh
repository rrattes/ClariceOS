#!/usr/bin/env bash
# ClariceOS — airootfs customization script
# Runs inside the airootfs chroot during `mkarchiso` build.
# Requires internet access at build time to download Fluent/Layan themes.

set -euo pipefail

echo "==> ClariceOS: applying Fluent/Layan themes..."

# ── Fluent GTK theme (GTK3 + GTK4) ─────────────────────────────────────────
# Download Fluent GTK theme from official upstream.
FLUENT_GTK_URL="https://github.com/vinceliuice/Fluent-gtk-theme/archive/refs/heads/master.tar.gz"

mkdir -p /usr/share/themes

echo "--> Downloading Fluent GTK theme..."
if curl -fsSL -o /tmp/fluent-gtk-theme.tar.gz "${FLUENT_GTK_URL}"; then
    mkdir -p /tmp/fluent-gtk-src
    tar -xzf /tmp/fluent-gtk-theme.tar.gz -C /tmp/fluent-gtk-src --strip-components=1
    bash /tmp/fluent-gtk-src/install.sh -d /usr/share/themes 2>/dev/null || true
    rm -rf /tmp/fluent-gtk-src /tmp/fluent-gtk-theme.tar.gz
    echo "    Fluent GTK theme installed."
else
    echo "    WARNING: Could not download Fluent GTK theme (no internet?). Skipping."
fi

echo "--> Downloading Tela icon theme..."
TELA_URL="https://github.com/vinceliuice/Tela-icon-theme/archive/refs/heads/master.tar.gz"
if curl -fsSL -o /tmp/tela-icon-theme.tar.gz "${TELA_URL}"; then
    mkdir -p /tmp/tela-src
    tar -xzf /tmp/tela-icon-theme.tar.gz -C /tmp/tela-src/ --strip-components=1
    # Install standard + dark variants to system-wide icons directory
    bash /tmp/tela-src/install.sh -d /usr/share/icons 2>/dev/null
    rm -rf /tmp/tela-src /tmp/tela-icon-theme.tar.gz
    for variant in Tela Tela-dark; do
        [ -d "/usr/share/icons/${variant}" ] && \
            gtk-update-icon-cache -f -t "/usr/share/icons/${variant}" 2>/dev/null || true
    done
    echo "    Tela icon theme installed (Tela, Tela-dark)."
else
    echo "    WARNING: Could not download Tela icon theme (no internet?). Skipping."
fi



# ── KDE color scheme ─────────────────────────────────────────────────────────
# Written inline — no download required. ClariceOS Layan-oriented palette.
mkdir -p /usr/share/color-schemes
cat > /usr/share/color-schemes/Layan.colors << 'COLORS'
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
ColorScheme=Layan
Name=Layan
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
echo "    Layan KDE color scheme written."

# ── dconf GNOME system-wide defaults ─────────────────────────────────────────
mkdir -p /etc/dconf/db/local.d /etc/dconf/profile

cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

cat > /etc/dconf/db/local.d/00-clariceos-theme << 'DCONF'
[org/gnome/desktop/interface]
gtk-theme='Fluent-Dark'
icon-theme='Tela-dark'
cursor-theme='Adwaita'
color-scheme='prefer-dark'
font-name='JetBrains Mono 11'
monospace-font-name='JetBrains Mono 11'
document-font-name='JetBrains Mono 11'

[org/gnome/desktop/wm/preferences]
theme='Fluent-Dark'
button-layout=':minimize,maximize,close'
titlebar-font='JetBrains Mono Bold 11'

[org/gnome/shell/extensions/user-theme]
name='Fluent-Dark'

[org/gnome/desktop/default-applications/terminal]
exec='kitty'
exec-arg=''
DCONF

dconf update && echo "    dconf database compiled."

# ── GTK3 settings (root — live session) ──────────────────────────────────────
mkdir -p /root/.config/gtk-3.0 /root/.config/gtk-4.0
cat > /root/.config/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=Fluent-Dark
gtk-icon-theme-name=Tela-dark
gtk-cursor-theme-name=Adwaita
gtk-font-name=JetBrains Mono 11
gtk-application-prefer-dark-theme=true
GTK
cp /root/.config/gtk-3.0/settings.ini /root/.config/gtk-4.0/settings.ini

# ── Kitty config (root — live session) ───────────────────────────────────────
mkdir -p /root/.config/kitty
cp /etc/skel/.config/kitty/kitty.conf /root/.config/kitty/kitty.conf

# ── Zsh as default shell for root (live session) ─────────────────────────────
if command -v zsh &>/dev/null && grep -q '^root:' /etc/passwd; then
    chsh -s "$(command -v zsh)" root && echo "    root shell set to zsh." || true
fi

# ── Starship config (root — live session) ─────────────────────────────────────
mkdir -p /root/.config
cp /etc/skel/.config/starship.toml /root/.config/starship.toml

# ── /etc/skel dotfiles (copied to every new user by Calamares) ───────────────
mkdir -p /etc/skel/.config/gtk-3.0 /etc/skel/.config/gtk-4.0
cp /root/.config/gtk-3.0/settings.ini /etc/skel/.config/gtk-3.0/settings.ini
cp /root/.config/gtk-3.0/settings.ini /etc/skel/.config/gtk-4.0/settings.ini

# KDE dotfiles
mkdir -p /etc/skel/.config

cat > /etc/skel/.config/kdeglobals << 'KDEGLOBALS'
[General]
ColorScheme=Layan
Name=Layan
shadeSortColumn=true
font=JetBrains Mono,11,-1,5,50,0,0,0,0,0
fixed=JetBrains Mono,11,-1,5,50,0,0,0,0,0
smallestReadableFont=JetBrains Mono,8,-1,5,50,0,0,0,0,0
toolBarFont=JetBrains Mono,10,-1,5,50,0,0,0,0,0
menuFont=JetBrains Mono,11,-1,5,50,0,0,0,0,0
activeFont=JetBrains Mono,11,-1,5,75,0,0,0,0,0
TerminalApplication=kitty
TerminalService=kitty.desktop
BrowserApplication=org.kde.falkon.desktop
BrowserService=org.kde.falkon.desktop

[KDE]
ColorScheme=Layan
contrast=4
widgetStyle=Breeze

[Icons]
Theme=Tela-dark

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
name=Layan
PLASMARC

cat > /etc/skel/.config/kwinrc << 'KWINRC'
[org.kde.kdecoration2]
library=org.kde.breeze
theme=Layan
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

echo "==> ClariceOS: Fluent/Layan theme configuration complete."

# ── Plymouth Clarice theme — generate colour assets ───────────────────────────
# The .plymouth descriptor and .script are shipped in airootfs.
# The three 1×1 PNG colour swatches must be generated at build time because
# binary files cannot be stored as plain text in the source tree.
echo "==> ClariceOS: generating Plymouth theme assets..."

PLYMOUTH_THEME_DIR="/usr/share/plymouth/themes/clariceos"
mkdir -p "${PLYMOUTH_THEME_DIR}"

python3 << 'PYEOF'
import struct, zlib, os

def make_png_1x1(r, g, b, path):
    """Write a minimal 1×1 RGB PNG to *path*."""
    def chunk(tag, data):
        buf = tag + data
        return (struct.pack('>I', len(data)) + buf +
                struct.pack('>I', zlib.crc32(buf) & 0xFFFFFFFF))

    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
    idat = chunk(b'IDAT', zlib.compress(bytes([0, r, g, b]), 9))
    iend = chunk(b'IEND', b'')
    with open(path, 'wb') as fh:
        fh.write(b'\x89PNG\r\n\x1a\n' + ihdr + idat + iend)

base = '/usr/share/plymouth/themes/clariceos'
make_png_1x1( 40,  42,  54, os.path.join(base, 'background.png'))   # #282a36
make_png_1x1(189, 147, 249, os.path.join(base, 'progress.png'))     # #bd93f9
make_png_1x1( 68,  71,  90, os.path.join(base, 'progress-bg.png')) # #44475a
print('    Plymouth PNG assets written.')
PYEOF

# Register the theme as the live-environment default
if command -v plymouth-set-default-theme &>/dev/null; then
    plymouth-set-default-theme clariceos 2>/dev/null \
        && echo "    Plymouth default theme set to: clariceos" \
        || echo "    WARNING: plymouth-set-default-theme failed (running outside initramfs?). plymouthd.conf already sets Theme=clariceos."
else
    echo "    plymouth-set-default-theme not available at build time — plymouthd.conf already sets Theme=clariceos."
fi

echo "==> ClariceOS: Plymouth theme ready."

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

# ── Post-install overlay files ────────────────────────────────────────────────
# These files conflict with packages (grml-zsh-config, calamares) when placed
# in airootfs, so they are created here after package installation.

echo "==> ClariceOS: writing post-install overlay files..."

# /etc/skel/.zshrc — overrides grml-zsh-config's skeleton
cat > /etc/skel/.zshrc << 'ZSHRC'
# ClariceOS — Zsh configuration
# grml-zsh-config provides the base (completion, keybindings, syntax-highlighting).
# This file adds autosuggestions, history substring search, and the Starship prompt.

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY INC_APPEND_HISTORY

# ── Zsh Autosuggestions ───────────────────────────────────────────────────────
# Suggest commands from history as you type (greyed-out ghost text)
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6272a4"          # Clarice neutral colour
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# ── History substring search ──────────────────────────────────────────────────
# Up/Down arrows search history by the already-typed prefix
if [[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="bg=#44475a,fg=#f8f8f2,bold"
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="bg=#ff5555,fg=#282a36,bold"
fi

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias lt='ls -lah --color=auto --sort=time'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# ── Starship prompt ───────────────────────────────────────────────────────────
# Initialised last so it overrides any prompt set by grml-zsh-config
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
ZSHRC

# /usr/share/applications/calamares.desktop — custom installer entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/calamares.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Version=1.5
Name=Install Clarice OS
GenericName=System Installer
Comment=Install Clarice OS to your computer
Exec=calamares
Icon=calamares
Terminal=false
Categories=System;
Keywords=install;installer;setup;clariceos;
DESKTOP

echo "==> ClariceOS: post-install overlay files written."

# ── Fix /etc/motd escape sequences ───────────────────────────────────────────
# The motd file uses literal \e (backslash + e) which terminals display
# as raw text. Convert to actual ESC bytes (0x1B) so colours render correctly.
if [ -f /etc/motd ]; then
    python3 -c "
content = open('/etc/motd').read()
open('/etc/motd', 'w').write(content.replace(r'\e', '\033'))
"
    echo "==> ClariceOS: /etc/motd escape sequences converted."
fi

# ── Live session user (GDM autologin) ────────────────────────────────────────
# Modern GDM (45+) refuses root autologin at application level regardless of
# PAM. Use a dedicated 'live' user with passwordless sudo instead.
if ! id -u live &>/dev/null; then
    useradd -m -G wheel,audio,video,storage,optical,network,scanner,uucp live
fi
passwd -d live
# Ensure account is unlocked for display-manager autologin.
passwd -u live 2>/dev/null || true

# GDM autologin can rely on this group on some setups.
groupadd -f autologin
usermod -aG autologin live 2>/dev/null || true

# Re-assert live GDM autologin values to avoid package/default overrides.
if [ -f /etc/gdm/custom.conf ]; then
    sed -i 's/^AutomaticLoginEnable=.*/AutomaticLoginEnable=True/' /etc/gdm/custom.conf
    if grep -q '^AutomaticLogin=' /etc/gdm/custom.conf; then
        sed -i 's/^AutomaticLogin=.*/AutomaticLogin=live/' /etc/gdm/custom.conf
    else
        printf '%s\n' 'AutomaticLogin=live' >> /etc/gdm/custom.conf
    fi
    if grep -q '^InitialSetupEnable=' /etc/gdm/custom.conf; then
        sed -i 's/^InitialSetupEnable=.*/InitialSetupEnable=False/' /etc/gdm/custom.conf
    else
        printf '%s\n' 'InitialSetupEnable=False' >> /etc/gdm/custom.conf
    fi
fi

# Copy skel configs to live home
cp -rT /etc/skel/ /home/live/
chown -R live:live /home/live/

# Suppress the post-install welcome assistant in the live session
# (it only makes sense after Calamares installs the system)
mkdir -p /home/live/.config/clariceos
touch /home/live/.config/clariceos/.welcome-done

# Prevent GNOME Shell from launching gnome-initial-setup on the live session.
# GDM is already configured with InitialSetupEnable=False (no pre-login wizard),
# but GNOME Shell itself checks for this marker at session start.
touch /home/live/.config/gnome-initial-setup-done

chown -R live:live /home/live/.config/

# Passwordless sudo for live user
echo 'live ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/live
chmod 440 /etc/sudoers.d/live

# Set zsh as shell for live user
if command -v zsh &>/dev/null; then
    grep -qxF "$(command -v zsh)" /etc/shells || echo "$(command -v zsh)" >> /etc/shells
    chsh -s "$(command -v zsh)" live && echo "    live shell set to zsh." || true
fi

echo "==> ClariceOS: live user created (autologin via GDM)."
