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
        for conf in kdeglobals plasmarc kwinrc breezerc; do
            [ -f "${home_dir}.config/${conf}" ] || \
                cp "/etc/skel/.config/${conf}" "${home_dir}.config/" 2>/dev/null || true
        done
    fi

    # Fix ownership
    chown -R "${username}:${username}" "${home_dir}.config/" 2>/dev/null || true
    echo ">>> Dracula theme applied for user: ${username}"
done

# ── Chaotic-AUR setup (installed system) ─────────────────────────────────────
# Chaotic-AUR provides pre-compiled AUR packages, eliminating the need to
# build pamac-aur, limine-snapper-sync, openrgb, etc. from source.
echo ">>> Configuring Chaotic-AUR on installed system..."

setup_chaotic_aur() {
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

setup_chaotic_aur || true

# ── Install pamac from Chaotic-AUR (no build from source needed) ──────────────
echo ">>> Installing pamac-aur..."
if grep -q "chaotic-aur" /etc/pacman.conf 2>/dev/null; then
    # Chaotic-AUR available — install directly via pacman
    pacman -S --noconfirm --needed pamac-aur 2>/dev/null \
        && echo "    pamac-aur installed from Chaotic-AUR." \
        || echo "    WARNING: pamac-aur not found in Chaotic-AUR."
else
    # Fallback: build from AUR via yay
    BUILD_USER_PAMAC=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd 2>/dev/null || true)
    if [ -n "${BUILD_USER_PAMAC}" ] && command -v yay &>/dev/null; then
        echo "${BUILD_USER_PAMAC} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-pamac-install
        sudo -u "${BUILD_USER_PAMAC}" yay -S --noconfirm --needed pamac-aur 2>/dev/null \
            && echo "    pamac-aur installed via yay." \
            || echo "    WARNING: pamac-aur installation failed."
        rm -f /etc/sudoers.d/99-pamac-install
    fi
fi

# ── Flatpak + Flathub ─────────────────────────────────────────────────────────
echo ">>> Configuring Flatpak + Flathub..."
if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
        && echo "    Flathub remote added." \
        || echo "    WARNING: Flathub remote add failed (no internet?)."
else
    echo "    WARNING: flatpak not found — skipping."
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
    has_nvidia=$(lspci 2>/dev/null | grep -ci "NVIDIA" || true)
    has_amd=$(lspci 2>/dev/null | grep -ciE "AMD/ATI|Radeon" || true)
    has_intel=$(lspci 2>/dev/null | grep -ci "Intel.*Graphics" || true)

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

# ── Plymouth Dracula theme — deploy to installed system ───────────────────────
echo ">>> Installing ClariceOS Plymouth theme..."
if command -v plymouth &>/dev/null; then
    PLYDIR="/usr/share/plymouth/themes/clariceos"
    mkdir -p "${PLYDIR}"

    # Theme descriptor
    cat > "${PLYDIR}/clariceos.plymouth" << 'PLYDESC'
[Plymouth Theme]
Name=ClariceOS
Description=ClariceOS — Dracula boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/clariceos
ScriptFile=/usr/share/plymouth/themes/clariceos/clariceos.script
PLYDESC

    # Plymouth script
    cat > "${PLYDIR}/clariceos.script" << 'PLYSCRIPT'
// ClariceOS Plymouth Theme — Dracula colour palette
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
