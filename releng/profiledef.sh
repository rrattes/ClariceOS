#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="ClariceOS"
iso_label="CLARICE_OS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="ClariceOS <https://ClariceOS.org>"
iso_application="ClariceOS Live/Rescue DVD"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/etc/calamares"]="0:0:755"
  ["/etc/calamares/settings.conf"]="0:0:644"
  ["/etc/calamares/branding"]="0:0:755"
  ["/etc/calamares/branding/clariceos"]="0:0:755"
  ["/etc/calamares/modules"]="0:0:755"
  ["/etc/calamares/scripts"]="0:0:755"
  ["/etc/calamares/scripts/configure-de.sh"]="0:0:755"
  ["/etc/calamares/scripts/install-bootloader.sh"]="0:0:755"
  ["/etc/calamares/scripts/limine-deploy.sh"]="0:0:755"
  ["/etc/calamares/scripts/btrfs-hooks.sh"]="0:0:755"
  ["/etc/calamares/scripts/setup-secureboot.sh"]="0:0:755"
  ["/etc/calamares/scripts/remove-live-pkgs.sh"]="0:0:755"
  ["/usr/local/bin/clariceos-autoupdate"]="0:0:755"
  ["/usr/local/bin/clariceos-hwdetect"]="0:0:755"
  ["/etc/skel/.config/kitty/kitty.conf"]="0:0:644"
  ["/etc/skel/.config/starship.toml"]="0:0:644"
  ["/etc/environment"]="0:0:644"
  ["/etc/systemd/zram-generator.conf"]="0:0:644"
  ["/etc/plymouth/plymouthd.conf"]="0:0:644"
  ["/usr/share/plymouth/themes/clariceos"]="0:0:755"
  ["/usr/share/plymouth/themes/clariceos/clariceos.plymouth"]="0:0:644"
  ["/usr/share/plymouth/themes/clariceos/clariceos.script"]="0:0:644"
  ["/etc/xdg/autostart/calamares.desktop"]="0:0:644"
  ["/etc/pam.d/gdm-autologin"]="0:0:644"
)
