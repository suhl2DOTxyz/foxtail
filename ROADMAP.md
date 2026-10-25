# Foxtail roadmap: toward a daily driver

**Goal:** by **v1.5**, Foxtail is something you can install on your main laptop and forget about. **v2.0** is the stable, polished release.

"Daily driver" means four things, in this order:

1. **It updates itself safely.** Bugs get fixed after install, and a bad update can be rolled back.
2. **It installs on real hardware.** That includes NVIDIA, laptops, dual-boot and encrypted disks.
3. **Everyday tasks never need a terminal.** That covers Wi-Fi, Bluetooth, displays, sound, printers, keyboards and users.
4. **It's fast and stable on real GPUs.** VMs are not the target.

Each release below moves one of those forward. ✅ = done.

---

## v1.1 (current)
- ✅ Desktop shell: menu bar, Dock, Control Center, Spotlight, Launchpad, Notification Center, lock screen
- ✅ Liquid Glass / classic glass, Tahoe-style layouts
- ✅ Graphical installer (erases the whole disk)
- ✅ Minimize to Dock, auto-lock, Spotlight file search

## v1.2: Updates (the foundation)
Today, an installed Foxtail can't receive Foxtail fixes. That's the #1 blocker.
- [ ] Package Foxtail itself: `foxtail-desktop` (shell + Hyprland config), `foxtail-theme`, `foxtail-branding`, `foxtail-installer`
- [ ] Host a signed pacman repo (`[foxtail]`), built by GitHub Actions on every tag
- [ ] Installed systems include the repo and the signing key
- [ ] **Software Update** pane in System Settings: checks pacman + Flatpak, shows changes, installs with one click, notifies when updates are ready
- [ ] **Btrfs + snapshots:** the installer creates subvolumes, a snapshot is taken before every update, and older snapshots are bootable from the boot menu
- [ ] Move per-user defaults out of `/etc/skel` so existing users get new defaults too

## v1.3: Real hardware
- [ ] GPU detection in the installer and live session: NVIDIA proprietary driver, plus Intel/AMD defaults
- [ ] Turn hardware rendering back on outside VMs, and test Liquid Glass performance on integrated GPUs
- [ ] Installer: **install alongside another OS**, **full-disk encryption (LUKS)**, keyboard layout, language, and Wi-Fi during install
- [ ] Laptops: power profiles, battery menu with time remaining, lid and suspend behaviour, hibernate, brightness/volume keys (partly done)
- [ ] Tested on at least 5 real machines (Intel, AMD, NVIDIA, and one older laptop)

## v1.4: No terminal needed
- [ ] **Displays:** resolution, scaling, refresh rate, multi-monitor arrangement, night shift
- [ ] **Bluetooth:** pairing UI with device icons and battery levels
- [ ] **Sound:** output/input device switcher in Control Center and Settings
- [ ] **Keyboard:** layouts and input sources, custom shortcuts
- [ ] **Users & Groups, Date & Time, Printers (CUPS), Default Apps**
- [ ] **⌘Tab app switcher** with icons, **Mission Control** (window overview), window snapping/tiling menu on the green button
- [ ] **Screenshot UI (⌘⇧5)** and screen recording
- [ ] Clipboard history

## v1.5: Daily-driver release
- [ ] Notification grouping, actions and reply
- [ ] Qt/KDE apps themed to match GTK apps
- [ ] Accessibility: larger text, zoom, high contrast, reduce motion
- [ ] Translations (the shell is English-only today)
- [ ] Crash and diagnostics reporting (local logs plus "Report a problem")
- [ ] Docs site: install guide, FAQ, troubleshooting
- [ ] Public beta: issue templates, a testers' channel, triage

## v2.0: Stable
- [ ] Fixed, reliable update cadence (stable vs. testing channels)
- [ ] Automated tests: QML lint in CI, an ISO boot test in a VM, installer test
- [ ] Performance budget: shell idle CPU and RAM, animation frame times on integrated GPUs
- [ ] Polish pass on every screen, with a consistent icon set
- [ ] Secure Boot support (signed bootloader/kernel)

---

## Known limitations (current)
- **Liquid Glass refracts only the wallpaper**, not windows behind a panel. Fixing this needs a compositor-side effect (a Hyprland plugin or shader pass).
- **App menus are generic.** File/Edit/View items send standard shortcuts, because Wayland has no global-menu protocol.
- **VMs use software rendering**, so animations are slower there than on real hardware.
