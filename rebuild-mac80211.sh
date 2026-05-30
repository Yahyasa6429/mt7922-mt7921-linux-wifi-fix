#!/usr/bin/env bash
# Rebuild a patched mac80211.ko (skip basic-MCS verification) for every
# installed kernel that has matching headers, and install it to that
# kernel's updates/ directory so it shadows the stock module.
#
# Non-destructive: the stock module under kernel/net/mac80211/ is never
# touched; reverting is just `uninstall.sh` (rm the updates/ copy + depmod).
#
# Variant-agnostic: works for linux, linux-zen, linux-lts, linux-hardened,
# etc. We build for ALL /usr/lib/modules/<ver>/ that have a build/ symlink
# (i.e. the matching *-headers package is installed), which is what makes
# this survive kernel upgrades when wired to the pacman hook.
#
# Optionally takes one or more KVERs as arguments to build only those.
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PATCH_FILE="$PATCH_DIR/skip-basic-mcs-check.patch"
LOG="/var/log/mac80211-mcs-patch.log"
SRC_CACHE="/var/cache/mac80211-mcs-patch"

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG" >&2; }

[[ -f "$PATCH_FILE" ]] || { log "patch file missing: $PATCH_FILE"; exit 1; }
mkdir -p "$SRC_CACHE"

# Which kernels to build for.
if [[ $# -gt 0 ]]; then
    KVERS=("$@")
else
    KVERS=()
    for d in /usr/lib/modules/*/; do
        KVERS+=("$(basename "$d")")
    done
fi

build_one() {
    local KVER="$1"
    local BUILD_DIR="/usr/lib/modules/$KVER/build"
    local INSTALL_DIR="/usr/lib/modules/$KVER/updates"
    if [[ ! -d "$BUILD_DIR" ]]; then
        log "[$KVER] no kernel headers (build/ missing) -> skip"
        return 0
    fi

    local KVER_BASE="${KVER%%-*}"      # 7.0.10-zen1-1-zen -> 7.0.10
    local MAJOR="${KVER_BASE%%.*}"     # 7
    local TARBALL="linux-$KVER_BASE.tar.xz"
    local URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/$TARBALL"

    # Cache the upstream source tarball per base version.
    if [[ ! -s "$SRC_CACHE/$TARBALL" ]]; then
        log "[$KVER] downloading $URL ..."
        curl -fSL "$URL" -o "$SRC_CACHE/$TARBALL"
    fi

    local WORK_DIR
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' RETURN

    log "[$KVER] extracting + patching mac80211 ($KVER_BASE) ..."
    tar xf "$SRC_CACHE/$TARBALL" -C "$WORK_DIR" "linux-$KVER_BASE/net/mac80211/"
    ( cd "$WORK_DIR/linux-$KVER_BASE" && patch -p1 < "$PATCH_FILE" )

    log "[$KVER] building ..."
    make -C "$BUILD_DIR" M="$WORK_DIR/linux-$KVER_BASE/net/mac80211" modules >>"$LOG" 2>&1

    log "[$KVER] installing patched mac80211.ko to updates/ ..."
    mkdir -p "$INSTALL_DIR"
    cp "$WORK_DIR/linux-$KVER_BASE/net/mac80211/mac80211.ko" "$INSTALL_DIR/"
    depmod "$KVER"
    log "[$KVER] done."
}

rc=0
for KVER in "${KVERS[@]}"; do
    build_one "$KVER" || { log "[$KVER] BUILD FAILED"; rc=1; }
done
exit $rc
