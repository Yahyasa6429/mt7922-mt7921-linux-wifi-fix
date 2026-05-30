# MT7921/MT7922 stuck at 54 Mbit/s on Linux — the "disabling HT" fix

**TL;DR** — If your MediaTek Wi-Fi card (MT7921 / MT7922, driver `mt7921e`) connects
fine but caps out around 10–20 Mbit/s on Linux while Windows gets hundreds of Mbit/s
to *gigabit* on the same machine and router, and `dmesg` shows:

```
wlanX: required MCSes not supported, disabling HT
```

…then your kernel's `mac80211` is refusing to use 802.11n/ac/ax (HT/VHT/HE) and
dropping to legacy 54 Mbit/s. This repo patches `mac80211` to skip that overly-strict
check and restores full speed. Build is non-destructive and reversible.

On the machine this was written on (ASUS TUF GAMING B650E-E WIFI, MT7922, `linux-zen`):

| | Before | After |
|---|---|---|
| `iw link` rate | `54.0 MBit/s`, 20 MHz, **no HT** | `1200 MBit/s`, 80 MHz, **HE-MCS 11 NSS 2** |
| `speedtest-cli` download | **16 Mbit/s** | **~430 Mbit/s** |

---

## Symptoms

- Wi-Fi associates and has internet, but download is a tiny fraction of your plan.
- Same computer dual-booting Windows gets full speed → not hardware, not the router.
- `iw dev wlanX link` shows a legacy rate and **20 MHz (no HT)**:
  ```
  rx bitrate: 54.0 MBit/s
  channel 157 (5785 MHz), width: 20 MHz (no HT)
  ```
- `iw dev wlanX info` may report a nonsense `txpower 3.00 dBm` (cosmetic on this
  driver — ignore it; it reads 3 dBm even at 1200 Mbit/s).
- The smoking gun, in `sudo dmesg`:
  ```
  wlanX: required MCSes not supported, disabling HT
  ```
- Reproduces on **both 2.4 GHz and 5 GHz**, on every AP, regardless of signal
  strength — because it's a client-side decision, not an RF problem.

## Root cause

Early-2025 `mac80211` added strict verification of the AP's **Basic HT-MCS Set**
(the "required" MCS rates in the HT Operation IE), in
`ieee80211_verify_sta_ht_mcs_support()` in `net/mac80211/mlme.c`.

Many **4×4 ISP gateways** (Xfinity XB8, and others — the box this was debugged on is
a Comcast-style gateway) advertise *required* MCS rates that need **3–4 spatial
streams**. A typical laptop/desktop card like the **MT7922 is only 2×2** (HT MCS
0–15). Per the letter of the spec, mac80211 then decides the station "can't meet the
basic rate set" and **disables HT entirely**, collapsing the link to 802.11a/g
54 Mbit/s.

Windows (and older Linux kernels) never enforced this, so they connect at full 2×2
speed — which is why Windows is fast and Linux is not. The basic-MCS set only governs
*management/broadcast* expectations; a 2×2 station transmits its unicast data on the
2×2 rates it does support perfectly well, so skipping the check is safe in practice.

## The fix

A one-hunk patch ([`skip-basic-mcs-check.patch`](./skip-basic-mcs-check.patch)) makes
`ieee80211_verify_sta_ht_mcs_support()` return `true` early instead of disabling HT:

```c
	if (!ht_op)
		return false;

+	/* Skip basic MCS set validation (4x4 AP + 2x2 STA). The STA still
+	 * works fine using its own supported rates for data transfer. */
+	return true;
	memcpy(&sta_ht_cap, &sband->ht_cap, sizeof(sta_ht_cap));
```

The patched `mac80211.ko` is built against your installed kernel headers and dropped
into `/usr/lib/modules/<ver>/updates/`, which **shadows** the stock module without
overwriting it. Reverting = delete that file + `depmod`.

## Install (Arch / Arch-based)

```bash
git clone <this-repo> mt7922-ht-mcs-fix
cd mt7922-ht-mcs-fix
sudo ./install.sh
```

`install.sh` will:
1. ensure `base-devel` / `bc` are present,
2. install the rebuild helper to `/usr/local/bin/rebuild-mac80211`,
3. install a **pacman hook** so the module is rebuilt automatically after any
   `linux` / `linux-zen` / `linux-lts` / `linux-hardened` (+ `-headers`) upgrade,
4. build + install the patched module for every installed kernel that has headers.

Then activate without rebooting:

```bash
sudo modprobe -r mt7921e mt7921_common mt792x_lib mt76_connac_lib mt76
sudo modprobe -r mac80211
sudo modprobe mac80211 && sudo modprobe mt7921e
```

(or just reboot). Verify:

```bash
iw dev wlanX link    # expect '80MHz HE-MCS ...' instead of '54.0 MBit/s ... no HT'
speedtest-cli --simple
```

## Revert

```bash
sudo ./uninstall.sh
```

Removes the hook, deletes the patched module from every kernel's `updates/`, runs
`depmod`. Stock `mac80211` returns on the next reload/reboot.

## Notes & caveats

- The rebuilt module is **out-of-tree tainted** (`OE` in `lsmod`/dmesg). Harmless.
- The pacman hook builds for **all installed kernels with headers**, so if you keep
  `linux-zen-headers` (etc.) installed, kernel upgrades stay fixed. If a future kernel
  refactors `mlme.c` and the patch fails to apply, the hook errors out and you simply
  fall back to stock (slow) behavior — nothing breaks; just re-check the patch.
- This is a **2×2 station** workaround. It does not "fake" rates — the card still only
  uses MCS it genuinely supports; it just stops mac80211 from throwing out HT/VHT/HE.
- Real upstream fix would be for mac80211 to not disable HT purely on a basic-MCS
  mismatch (or for ISP gateways to stop advertising 4-stream basic rates).

## Tested on

- ASUS TUF GAMING B650E-E WIFI, MediaTek MT7922 (`14c3:0616`, `mt7921e`)
- `linux-zen` 7.0.10, `linux-firmware-mediatek` 20260519
- Comcast/Xfinity-style 4×4 gateway
- 16 Mbit/s → ~430 Mbit/s download

## Credits & attribution

- **The patch and the original DKMS/pacman-hook approach** come from
  **WoodyWoodster/mac80211-mcs-patch**: <https://github.com/WoodyWoodster/mac80211-mcs-patch>.
  This repo reuses that patch verbatim and extends the tooling to handle non-default
  kernels (e.g. `linux-zen`) and to rebuild for all installed kernels.
- Arch Linux forum thread that surfaced the fix —
  *"mt7921e: stuck at 54 Mbps max, on both 2.4 GHz and 5 GHz"*:
  <https://bbs.archlinux.org/viewtopic.php?pid=2296485>
- The mac80211 change that introduced the strict check —
  *"wifi: mac80211: add HT and VHT basic set verification"* (linux-wireless, Feb 2025):
  <https://patchwork.kernel.org/project/linux-wireless/patch/20250204193721.7dfdeb1235bb.I66bcf6c2de3b9d3325e4ffd9f573f4cd26ce5685@changeid/>

## License

The patch follows the Linux kernel's **GPL-2.0**. Scripts and docs here are released
under GPL-2.0 as well.
