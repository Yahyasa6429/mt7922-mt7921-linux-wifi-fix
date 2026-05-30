#!/usr/bin/env bash
# Remove the patched mac80211 and restore the stock module. Run with sudo.
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo ./uninstall.sh)"; exit 1; fi

echo "==> Removing pacman hook ..."
rm -f /etc/pacman.d/hooks/91-mac80211-mcs-patch.hook

echo "==> Removing patched modules from every kernel's updates/ ..."
shopt -s nullglob
for f in /usr/lib/modules/*/updates/mac80211.ko; do
    kver="$(basename "$(dirname "$(dirname "$f")")")"
    echo "    $f"
    rm -f "$f"
    depmod "$kver"
done

echo "==> Removing helper files ..."
rm -f /usr/local/bin/rebuild-mac80211
rm -rf /usr/local/share/mac80211-mcs-patch

cat <<'MSG'

==> Reverted. The stock mac80211 will load on next module reload / reboot.
    To apply now:
      sudo modprobe -r mt7921e mt7921_common mt792x_lib mt76_connac_lib mt76
      sudo modprobe -r mac80211
      sudo modprobe mac80211 && sudo modprobe mt7921e
    (HT will be disabled again on 4x4 APs — that is the stock behavior.)
MSG
