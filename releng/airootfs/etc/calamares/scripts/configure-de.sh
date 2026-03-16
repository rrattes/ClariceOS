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

# ── Install pamac (AUR graphical package manager) ────────────────────────────
echo ">>> Installing pamac-aur via yay..."

install_pamac() {
    # yay is in the extra repo and was installed as a live package.
    # It is also included in packages.x86_64 so it ships in the installed system.
    if ! command -v yay &>/dev/null; then
        echo "    WARNING: yay not found — skipping pamac installation."
        return 1
    fi

    # Find the first non-root user (the one created during installation)
    local BUILD_USER
    BUILD_USER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd 2>/dev/null || true)

    if [ -z "${BUILD_USER}" ]; then
        echo "    WARNING: no non-root user found — cannot run yay as unprivileged user."
        return 1
    fi

    # Grant temporary NOPASSWD sudo so yay can call pacman
    echo "${BUILD_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-pamac-install

    # Run yay as the target user
    sudo -u "${BUILD_USER}" yay -S --noconfirm --needed pamac-aur 2>/dev/null \
        && echo "    pamac-aur installed successfully." \
        || { echo "    WARNING: pamac-aur installation failed."; rm -f /etc/sudoers.d/99-pamac-install; return 1; }

    rm -f /etc/sudoers.d/99-pamac-install
}

install_pamac || true

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
