#!/usr/bin/env bash
# Install the patched mac80211 (skip basic-MCS check) and wire it up so it
# survives kernel upgrades. Run with sudo.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo ./install.sh)"; exit 1; fi

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SHARE="/usr/local/share/mac80211-mcs-patch"

echo "==> Checking build dependencies (base-devel, bc, git headers)..."
need=()
command -v gcc  >/dev/null || need+=(base-devel)
command -v make >/dev/null || need+=(base-devel)
command -v bc   >/dev/null || need+=(bc)
if ((${#need[@]})); then
    echo "    Installing: ${need[*]}"
    pacman -S --needed --noconfirm "${need[@]}"
fi
# Make sure at least one running-kernel header set exists.
if [[ ! -d "/usr/lib/modules/$(uname -r)/build" ]]; then
    echo "!!! No headers for running kernel $(uname -r)."
    echo "    Install the matching *-headers package (e.g. linux-zen-headers) and re-run."
    exit 1
fi

echo "==> Installing files to $SHARE ..."
mkdir -p "$SHARE"
install -m 0644 "$SRC/skip-basic-mcs-check.patch" "$SHARE/"
install -m 0755 "$SRC/rebuild-mac80211.sh"        "$SHARE/"
ln -sf "$SHARE/rebuild-mac80211.sh" /usr/local/bin/rebuild-mac80211

echo "==> Installing pacman hook (rebuilds on kernel upgrades) ..."
mkdir -p /etc/pacman.d/hooks
install -m 0644 "$SRC/91-mac80211-mcs-patch.hook" /etc/pacman.d/hooks/

echo "==> Building patched mac80211 for all installed kernels ..."
/usr/local/bin/rebuild-mac80211

cat <<'MSG'

==> Done. The patched module is installed to each kernel's updates/ dir.

To activate now without rebooting:
    sudo modprobe -r mt7921e mt7921_common mt792x_lib mt76_connac_lib mt76
    sudo modprobe -r mac80211
    sudo modprobe mac80211 && sudo modprobe mt7921e
  (or just reboot)

Verify:   iw dev <wlanX> link        # expect 80MHz HE/VHT, not "54.0 MBit/s (no HT)"
Revert:   sudo ./uninstall.sh
MSG
