#!/bin/bash
# ClariceOS — post-install desktop environment + theme configuration
# Runs inside the chroot of the newly installed system via Calamares shellprocess.

set -euo pipefail

GNOME_INSTALLED=false
KDE_INSTALLED=false
GNOME_GTK_THEME="Fluent-Dark"
GNOME_CURSOR_THEME="Adwaita"
POSTINSTALL_DIR="/etc/calamares/scripts/postinstall"

pacman -Q gnome-shell    &>/dev/null 2>&1 && GNOME_INSTALLED=true
pacman -Q plasma-desktop &>/dev/null 2>&1 && KDE_INSTALLED=true

echo "ClariceOS: GNOME=$GNOME_INSTALLED  KDE=$KDE_INSTALLED"

# Load optional post-install modules (PR1: theme modularization).
[ -f "${POSTINSTALL_DIR}/20-theme-gnome.sh" ] && source "${POSTINSTALL_DIR}/20-theme-gnome.sh"
[ -f "${POSTINSTALL_DIR}/21-theme-kde.sh" ] && source "${POSTINSTALL_DIR}/21-theme-kde.sh"
[ -f "${POSTINSTALL_DIR}/40-repositories.sh" ] && source "${POSTINSTALL_DIR}/40-repositories.sh"
[ -f "${POSTINSTALL_DIR}/41-pamac.sh" ] && source "${POSTINSTALL_DIR}/41-pamac.sh"
[ -f "${POSTINSTALL_DIR}/50-flatpak.sh" ] && source "${POSTINSTALL_DIR}/50-flatpak.sh"

# ── Display manager setup ─────────────────────────────────────────────────────
if $KDE_INSTALLED; then
    echo ">>> Configuring KDE Plasma + Plasma Login Manager"

    systemctl enable  plasmalogin.service 2>/dev/null || true
    systemctl disable gdm.service          2>/dev/null || true
    systemctl disable sddm.service         2>/dev/null || true

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
    systemctl disable plasmalogin.service 2>/dev/null || true
    systemctl disable sddm.service        2>/dev/null || true

    # Switch GDM autologin from the live 'live' user to the installed user.
    # The live ISO ships AutomaticLogin=live; we replace it with the real user.
    INSTALLED_USER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd 2>/dev/null || true)
    GDM_CONF="/etc/gdm/custom.conf"
    if [ -f "$GDM_CONF" ] && [ -n "${INSTALLED_USER}" ]; then
        sed -i "s/^AutomaticLogin=.*/AutomaticLogin=${INSTALLED_USER}/" "$GDM_CONF"
        echo ">>> GDM autologin set to installed user: ${INSTALLED_USER}"
    elif [ -f "$GDM_CONF" ]; then
        # No real user found — disable autologin to avoid a broken state
        sed -i 's/^AutomaticLoginEnable=True/AutomaticLoginEnable=False/' "$GDM_CONF"
        sed -i '/^AutomaticLogin=/d' "$GDM_CONF"
        echo ">>> GDM autologin disabled (no installed user found)"
    fi

else
    echo "WARNING: No desktop environment detected. Skipping DM configuration."
fi

# ── Theme modules (PR1) ───────────────────────────────────────────────────────
if $GNOME_INSTALLED && command -v apply_gnome_theme >/dev/null 2>&1; then
    apply_gnome_theme "${GNOME_GTK_THEME}" "${GNOME_CURSOR_THEME}"
fi

# ── Tela icon theme ───────────────────────────────────────────────────────────
echo ">>> Installing Tela icon theme..."
TELA_URL="https://github.com/vinceliuice/Tela-icon-theme/archive/refs/heads/master.tar.gz"
if curl -fsSL -o /tmp/tela-icon-theme.tar.gz "${TELA_URL}" 2>/dev/null; then
    mkdir -p /tmp/tela-src
    tar -xzf /tmp/tela-icon-theme.tar.gz -C /tmp/tela-src/ --strip-components=1
    bash /tmp/tela-src/install.sh -d /usr/share/icons 2>/dev/null
    rm -rf /tmp/tela-src /tmp/tela-icon-theme.tar.gz
    for variant in Tela Tela-dark; do
        [ -d "/usr/share/icons/${variant}" ] && \
            gtk-update-icon-cache -f -t "/usr/share/icons/${variant}" 2>/dev/null || true
    done
    echo "    Tela icon theme installed."
else
    echo "    WARNING: Could not download Tela icon theme (no internet?). Skipping."
fi

if $KDE_INSTALLED && command -v apply_kde_theme >/dev/null 2>&1; then
    apply_kde_theme
fi

# ── Apply desktop theme defaults to each new user ─────────────────────────────
# /etc/skel dotfiles were already copied by the Calamares users module.
# This block applies gsettings overrides for GNOME users so the theme
# is active on first login without requiring a dconf write by the user.
for home_dir in /home/*/; do
    [ -d "$home_dir" ] || continue
    username=$(basename "$home_dir")

    # Skip gnome-initial-setup on first login — without this file GNOME Shell
    # launches the setup wizard instead of the normal desktop session.
    mkdir -p "${home_dir}.config"
    touch "${home_dir}.config/gnome-initial-setup-done" 2>/dev/null || true

    # GTK3
    mkdir -p "${home_dir}.config/gtk-3.0"
    [ -f "${home_dir}.config/gtk-3.0/settings.ini" ] || \
        cp /etc/skel/.config/gtk-3.0/settings.ini "${home_dir}.config/gtk-3.0/" 2>/dev/null || true

    # GTK4
    mkdir -p "${home_dir}.config/gtk-4.0"
    [ -f "${home_dir}.config/gtk-4.0/settings.ini" ] || \
        cp /etc/skel/.config/gtk-4.0/settings.ini "${home_dir}.config/gtk-4.0/" 2>/dev/null || true

    # Kitty config
    mkdir -p "${home_dir}.config/kitty"
    [ -f "${home_dir}.config/kitty/kitty.conf" ] || \
        cp /etc/skel/.config/kitty/kitty.conf "${home_dir}.config/kitty/" 2>/dev/null || true

    # Zsh config
    [ -f "${home_dir}.zshrc" ] || \
        cp /etc/skel/.zshrc "${home_dir}.zshrc" 2>/dev/null || true

    # Starship prompt config
    [ -f "${home_dir}.config/starship.toml" ] || \
        cp /etc/skel/.config/starship.toml "${home_dir}.config/starship.toml" 2>/dev/null || true

    # KDE profile: force-apply curated defaults so first boot is already customized.
    if $KDE_INSTALLED; then
        for conf in kdeglobals plasmarc kwinrc; do
            [ -f "/etc/skel/.config/${conf}" ] \
                && cp -f "/etc/skel/.config/${conf}" "${home_dir}.config/${conf}" 2>/dev/null \
                || true
        done
    fi

    # Set zsh as the login shell for this user
    if command -v zsh &>/dev/null; then
        ZSH_PATH="$(command -v zsh)"
        # Ensure zsh is listed in /etc/shells
        grep -qxF "${ZSH_PATH}" /etc/shells || echo "${ZSH_PATH}" >> /etc/shells
        chsh -s "${ZSH_PATH}" "${username}" 2>/dev/null \
            && echo "    Shell set to zsh for: ${username}" || true
    fi

    # Fix ownership
    chown -R "${username}:${username}" "${home_dir}.config/" "${home_dir}.zshrc" 2>/dev/null || true
    echo ">>> Theme profile + zsh applied for user: ${username}"
done

# ── Set zsh as default shell for root in installed system ─────────────────────
if command -v zsh &>/dev/null; then
    ZSH_PATH="$(command -v zsh)"
    grep -qxF "${ZSH_PATH}" /etc/shells || echo "${ZSH_PATH}" >> /etc/shells
    chsh -s "${ZSH_PATH}" root 2>/dev/null && echo ">>> root shell set to zsh." || true
    # Copy zsh + starship configs for root
    mkdir -p /root/.config
    [ -f /root/.zshrc ] || cp /etc/skel/.zshrc /root/.zshrc 2>/dev/null || true
    [ -f /root/.config/starship.toml ] || \
        cp /etc/skel/.config/starship.toml /root/.config/starship.toml 2>/dev/null || true
fi

# ── Repository and package modules (PR2) ──────────────────────────────────────
if command -v setup_chaotic_aur >/dev/null 2>&1; then
    setup_chaotic_aur || true
fi
if command -v install_pamac >/dev/null 2>&1; then
    install_pamac
fi
if command -v setup_flatpak_flathub >/dev/null 2>&1; then
    setup_flatpak_flathub
fi

# ── AppArmor ──────────────────────────────────────────────────────────────────
echo ">>> Enabling AppArmor..."
if command -v apparmor_status &>/dev/null || pacman -Q apparmor &>/dev/null 2>&1; then
    systemctl enable apparmor.service 2>/dev/null \
        && echo "    apparmor.service enabled." \
        || echo "    WARNING: apparmor.service could not be enabled."
else
    echo "    AppArmor not installed — skipping."
fi

# ── GPU Driver Detection ───────────────────────────────────────────────────────
echo ">>> Detecting GPU and installing drivers..."

BUILD_USER_GPU=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd 2>/dev/null || true)

install_gpu_drivers() {
    local has_nvidia has_amd has_intel
    # Use || echo 0 so the variable is always a valid integer even if lspci
    # is unavailable (pciutils not installed) or if pipefail is active.
    has_nvidia=$(lspci 2>/dev/null | grep -ci "NVIDIA" || echo 0)
    has_amd=$(lspci 2>/dev/null | grep -ciE "AMD/ATI|Radeon" || echo 0)
    has_intel=$(lspci 2>/dev/null | grep -ci "Intel.*Graphics" || echo 0)

    # NVIDIA — proprietary driver via yay (supports all current cards)
    if [ "${has_nvidia}" -gt 0 ]; then
        echo "    NVIDIA GPU detected — installing nvidia-dkms..."
        if [ -n "${BUILD_USER_GPU}" ]; then
            echo "${BUILD_USER_GPU} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-gpu-install
            sudo -u "${BUILD_USER_GPU}" yay -S --noconfirm --needed \
                nvidia-dkms nvidia-utils nvidia-settings lib32-nvidia-utils 2>/dev/null \
                && echo "    NVIDIA drivers installed." \
                || echo "    WARNING: NVIDIA driver install failed."
            rm -f /etc/sudoers.d/99-gpu-install
        fi
        # Enable DRM kernel mode setting (required for Wayland)
        mkdir -p /etc/modprobe.d
        echo "options nvidia-drm modeset=1 fbdev=1" > /etc/modprobe.d/nvidia.conf
        # Add nvidia modules to mkinitcpio for early KMS
        if grep -q "^MODULES=" /etc/mkinitcpio.conf 2>/dev/null; then
            sed -i 's/^MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm \1)/' \
                /etc/mkinitcpio.conf
        fi
        # Rebuild initramfs with nvidia modules
        mkinitcpio -P 2>/dev/null || true
        echo "    NVIDIA: DRM modeset enabled, early KMS configured."
    fi

    # AMD — open-source (amdgpu already in mesa); add Vulkan + VA-API
    if [ "${has_amd}" -gt 0 ]; then
        echo "    AMD GPU detected — installing Vulkan + VA-API drivers..."
        pacman -S --noconfirm --needed \
            vulkan-radeon lib32-vulkan-radeon \
            libva-mesa-driver mesa-vdpau 2>/dev/null \
            && echo "    AMD Vulkan/VA-API drivers installed." \
            || true
    fi

    # Intel — iGPU Vulkan + hardware video decode
    if [ "${has_intel}" -gt 0 ]; then
        echo "    Intel GPU detected — installing Vulkan + media drivers..."
        pacman -S --noconfirm --needed \
            vulkan-intel intel-media-driver \
            libva-intel-driver 2>/dev/null \
            && echo "    Intel Vulkan/media drivers installed." \
            || true
    fi
}

install_gpu_drivers || true

# ── Plymouth Clarice theme — deploy to installed system ───────────────────────
echo ">>> Installing ClariceOS Plymouth theme..."
if command -v plymouth &>/dev/null; then
    PLYDIR="/usr/share/plymouth/themes/clariceos"
    mkdir -p "${PLYDIR}"

    # Theme descriptor
    cat > "${PLYDIR}/clariceos.plymouth" << 'PLYDESC'
[Plymouth Theme]
Name=ClariceOS
Description=ClariceOS — Clarice boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/clariceos
ScriptFile=/usr/share/plymouth/themes/clariceos/clariceos.script
PLYDESC

    # Plymouth script
    cat > "${PLYDIR}/clariceos.script" << 'PLYSCRIPT'
// ClariceOS Plymouth Theme — Clarice colour palette
width  = Window.GetWidth();
height = Window.GetHeight();

bg     = Image("background.png");
bg     = bg.Scale(width, height);
bg_spr = Sprite(bg);
bg_spr.SetZ(-100);

title     = Image.Text("ClariceOS", 0.973, 0.973, 0.898, 1, "Sans Bold 28");
title_spr = Sprite(title);
title_spr.SetX(Math.Int(width  / 2 - title.GetWidth()  / 2));
title_spr.SetY(Math.Int(height / 2 - title.GetHeight() / 2 - 40));

bar_w = Math.Int(width * 0.50);
bar_h = 4;
bar_x = Math.Int((width - bar_w) / 2);
bar_y = Math.Int(height * 0.67);

track     = Image("progress-bg.png").Scale(bar_w, bar_h);
track_spr = Sprite(track);
track_spr.SetX(bar_x);
track_spr.SetY(bar_y);
track_spr.SetZ(0);

fill_spr = Sprite();
fill_spr.SetX(bar_x);
fill_spr.SetY(bar_y);
fill_spr.SetZ(1);

fun boot_progress_callback(time, progress) {
    w = Math.Int(bar_w * progress);
    if (w < 1) w = 1;
    fill_spr.SetImage(Image("progress.png").Scale(w, bar_h));
}
Plymouth.SetBootProgressFunction(boot_progress_callback);

msg_spr = Sprite();
fun message_callback(text) {
    img = Image.Text(text, 0.973, 0.973, 0.898, 0.65, "Sans 10");
    msg_spr.SetImage(img);
    msg_spr.SetX(Math.Int(width / 2 - img.GetWidth() / 2));
    msg_spr.SetY(bar_y + bar_h + 12);
}
Plymouth.SetMessageFunction(message_callback);
PLYSCRIPT

    # Generate 1×1 PNG colour swatches using Python3 stdlib (no Pillow needed)
    python3 << 'PYEOF'
import struct, zlib, os

def make_png_1x1(r, g, b, path):
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
make_png_1x1( 40,  42,  54, os.path.join(base, 'background.png'))
make_png_1x1(189, 147, 249, os.path.join(base, 'progress.png'))
make_png_1x1( 68,  71,  90, os.path.join(base, 'progress-bg.png'))
PYEOF

    plymouth-set-default-theme clariceos 2>/dev/null \
        && echo "    Plymouth theme set to: clariceos" \
        || echo "    WARNING: plymouth-set-default-theme failed; plymouthd.conf already specifies clariceos."
else
    echo "    Plymouth not installed — skipping theme deployment."
fi

# ── Plymouth mkinitcpio hook ───────────────────────────────────────────────────
echo ">>> Configuring Plymouth boot splash..."
if command -v plymouth &>/dev/null && [ -f /etc/mkinitcpio.conf ]; then
    # Add 'plymouth' hook after 'base udev' and before 'autodetect'
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sed -i 's/\(HOOKS=.*\)\budev\b/\1udev plymouth/' /etc/mkinitcpio.conf \
            && echo "    Plymouth hook added to mkinitcpio." \
            || echo "    WARNING: could not inject plymouth hook."
        mkinitcpio -P 2>/dev/null || true
    else
        echo "    Plymouth hook already present."
    fi
fi

# ── Timeshift for ext4 systems ────────────────────────────────────────────────
echo ">>> Configuring snapshot tool..."
ROOT_FS=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "")

if [ "${ROOT_FS}" = "btrfs" ]; then
    echo "    btrfs root — snapper already configured by installer."
elif command -v timeshift &>/dev/null; then
    echo "    ext4/other root — configuring Timeshift (rsync mode)..."
    # Create a basic Timeshift config for rsync mode with monthly snapshots
    mkdir -p /etc/timeshift
    cat > /etc/timeshift/timeshift.json << 'TSCONF'
{
  "backup_device_uuid" : "",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "btrfs_use_qgroup" : "true",
  "schedule_monthly" : "true",
  "schedule_weekly" : "true",
  "schedule_daily" : "false",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "snapshot_size" : "",
  "snapshot_unit" : "",
  "exclude" : [
    "+ /root/**",
    "+ /home/**",
    "- /root/**",
    "- /home/**"
  ],
  "exclude-apps" : []
}
TSCONF
    systemctl enable cronie.service 2>/dev/null || \
    systemctl enable cron.service   2>/dev/null || true
    echo "    Timeshift configured (rsync, weekly+monthly snapshots)."
fi

echo ">>> ClariceOS post-install configuration complete."
