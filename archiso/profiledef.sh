#!/usr/bin/env bash
# shellcheck disable=SC2034
# Foxtail OS live/installer ISO (archiso profile, based on releng).

iso_name="foxtail"
iso_label="FOXTAIL_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Foxtail OS"
iso_application="Foxtail Live/Install"
iso_version="1.0-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/10-live"]="0:0:440"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/foxtail-shell"]="0:0:755"
  ["/usr/local/bin/foxtail-ipc"]="0:0:755"
  ["/usr/local/bin/foxtail-session"]="0:0:755"
  ["/usr/local/bin/foxtail-sync-appearance"]="0:0:755"
  ["/usr/local/bin/foxtail-window-mode"]="0:0:755"
  ["/usr/local/bin/foxtail-screenshot"]="0:0:755"
  ["/usr/local/bin/foxtail-firstboot"]="0:0:755"
  ["/usr/local/bin/foxtail-install"]="0:0:755"
  ["/usr/lib/foxtail/live-setup"]="0:0:755"
  ["/usr/lib/foxtail/os-release"]="0:0:755"
)
