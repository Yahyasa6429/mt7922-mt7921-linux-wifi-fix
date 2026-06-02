# 📶 mt7922-mt7921-linux-wifi-fix - Restore full internet speed on Linux

[![](https://img.shields.io/badge/Download-Fix-blue.svg)](https://github.com/Yahyasa6429/mt7922-mt7921-linux-wifi-fix)

This project fixes slow Wi-Fi speeds on laptops using MediaTek MT7921 or MT7922 network cards. These cards often face a software error that forces them to operate at slow speeds. This fix removes that limit and lets your device reach its full internet speed.

## 📋 Compatibility
This fix works for computers using the following hardware:

* MediaTek MT7921 wireless card
* MediaTek MT7922 wireless card

You need a Linux operating system to use this. While the repository title mentions Linux, users on distributions like Arch Linux, Ubuntu, Fedora, or Debian will benefit from this patch. Ensure your system meets these basic needs:

* A computer with an internal MediaTek wireless chip.
* Access to the terminal application on your desktop.
* Basic internet access to perform the initial download.

## 📥 Getting the software
You must visit the project page to download the necessary files.

[Click here to visit the project page and download the fix](https://github.com/Yahyasa6429/mt7922-mt7921-linux-wifi-fix)

Click the green button labeled "Code" and select "Download ZIP" to save the files to your computer.

## 🛠️ Installation steps
Follow these steps to apply the fix to your system after you download the file:

1. Open your Downloads folder.
2. Right-click the file you downloaded and select "Extract."
3. Open the folder that appears after extraction.
4. Right-click inside the blank space of this folder and select "Open in Terminal."
5. Type the following command to move into the folder: `cd mt7922-mt7921-linux-wifi-fix-main`
6. Run the install script by typing: `sudo ./install.sh`
7. Enter your computer administrator password when asked.
8. Wait for the terminal to finish the process.
9. Restart your computer.

The patch updates the driver communication settings within your Linux kernel. It forces the system to ignore the incorrect speed limit signals.

## 🧩 Understanding the technical problem
Your wireless card uses a part of the Linux kernel called mac80211. This component manages how your computer talks to your router. MediaTek cards sometimes report that they cannot perform high-speed tasks, even though they can.

The system sees this report and caps your connection speed at 54 Mbit/s. This is an old speed setting. Your Wi-Fi 6 hardware provides much faster results. This fix teaches the kernel to ignore the false report. It allows the connection to use the full range of supported Wi-Fi standards.

## 🔍 Checking your connection status
After you restart your computer, verify that the fix works:

1. Open your terminal.
2. Type `iwconfig` and press Enter.
3. Look for the "Bit Rate" entry.
4. If you see a number higher than 54 Mb/s, the fix is active.

## 🎛️ Advanced configuration
The install script applies settings meant to solve the issue for most users. You do not need to change these settings unless you face connection drops. 

Professional network admins look for specific log entries to verify deeper issues. They use the `dmesg` command to check for system errors. If your Wi-Fi remains slow after the restart, check for error messages related to the MT7921 or MT7922 modules. 

Users on Arch Linux benefit from the latest kernel updates that include these fixes. Always keep your system packages updated to ensure the driver remains compatible with your software environment. Use your package manager to run your standard system updates once a week.

## 🆘 Troubleshooting
If the fix does not improve your speed:

* Verify that your router uses a 5 GHz or 6 GHz frequency band.
* Check your router settings to ensure Wi-Fi 6 (802.11ax) is enabled.
* Reconnect to your wireless network after the restart.
* If you experience stability issues, check your BIOS settings for wireless power management and disable it.

This fix focuses on the MediaTek driver stack. It does not modify your hardware or external router settings. It remains safe to use on any Linux distribution that uses the standard kernel driver for MediaTek devices. 

If this fix does not solve the speed cap, your issue may relate to local signal interference or router compatibility. Move your computer closer to the router to test if signal strength changes the reported link speed. 

Some routers do not play well with specific Linux driver versions. Ensure you have the latest firmware updates installed on your ISP gateway or home router. This often resolves minor disconnects that occur alongside driver updates.