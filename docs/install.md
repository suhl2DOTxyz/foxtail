# Installing Foxtail

## What you need
- A 64-bit PC that starts in **UEFI** mode (almost every PC from 2012 on). Macs with Intel chips work too; Apple Silicon Macs don't.
- **4 GB of memory** or more (8 GB is comfortable).
- **20 GB** of free disk space.
- A USB stick of **4 GB** or more. It will be erased.

Graphics: Intel and AMD work out of the box. NVIDIA works on GTX 16-series, RTX and newer (the open driver is installed automatically). Older NVIDIA cards are not supported.

## 1. Download
Get both ISO parts and `SHA256SUMS` from the [latest release](https://github.com/suhl2DOTxyz/foxtail/releases/latest). GitHub limits files to 2 GiB, so the ISO comes in two pieces. Join them:

- **Linux / macOS:** `cat foxtail-*.iso.part0 foxtail-*.iso.part1 > foxtail.iso`
- **Windows (Command Prompt):** `copy /b foxtail-*.iso.part0 + foxtail-*.iso.part1 foxtail.iso`

Optionally check it: `sha256sum foxtail.iso` should match the first line of `SHA256SUMS`.

## 2. Make a USB stick
- **Windows:** [Rufus](https://rufus.ie). Pick the ISO, and choose **DD Image mode** when asked.
- **Any system:** [Ventoy](https://ventoy.net). Copy the ISO onto the stick.
- **macOS / Linux:** [balenaEtcher](https://etcher.balena.io), or `sudo dd if=foxtail.iso of=/dev/sdX bs=4M status=progress` (be sure `/dev/sdX` is the stick).

## 3. Start from the stick
Plug it in, restart, and open your PC's boot menu (usually **F12**, **F11**, **Esc** or **F8** while the logo shows; on Macs hold **⌥ Option**). Choose the USB stick, in UEFI mode.

If Foxtail doesn't start, turn off **Secure Boot** in your PC's firmware settings (Foxtail doesn't support it yet).

## 4. Install
Foxtail starts a live desktop, and the installer opens by itself. It asks for:

1. **Language and keyboard**, applied right away, so your password is typed with the right layout.
2. **Destination:**
   - **Erase disk** uses the whole disk for Foxtail. Everything on it is deleted.
   - **Install alongside** puts Foxtail in free space next to another system (like Windows), and a menu lets you choose at startup. Make the free space first (in Windows: *Disk Management ▸ Shrink Volume*); Foxtail doesn't resize partitions.
   - **Encrypt the disk** asks for your password every time the computer starts. If you forget it, your files can't be recovered.
3. **Your account**: name, password and computer name.
4. **Time zone.**

Installing takes a few minutes and works without an internet connection. Restart, take the USB stick out, and log in.

## After installing
- Connect to Wi-Fi from the menu bar.
- **fox menu ▸ Software Update** gets the latest fixes. Foxtail checks by itself too.
- More apps: **App Store** (Flatpak) in the fox menu.
