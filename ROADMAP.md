# Foxtail roadmap: toward a daily driver

**Goal:** **v2.0** is the stable, daily-driver release: something you can install on your main laptop and forget about. Every 1.x release builds toward it.

"Daily driver" means four things, in this order:

1. **It updates itself safely.** Bugs get fixed after install, and a bad update can be rolled back.
2. **It installs on real hardware.** That includes NVIDIA, laptops, dual-boot and encrypted disks.
3. **Everyday tasks never need a terminal.** That covers Wi-Fi, Bluetooth, displays, sound, printers, keyboards and users.
4. **It's fast and stable on real GPUs.** VMs are not the target.

✅ = done (tested in a VM), 🟡 = done but not yet tested on real hardware.

---

## v1.1
- ✅ Desktop shell: menu bar, Dock, Control Center, Spotlight, Launchpad, Notification Center, lock screen
- ✅ Liquid Glass / classic glass, Tahoe-style layouts
- ✅ Graphical installer
- ✅ Minimize to Dock, auto-lock, Spotlight file search

## v1.2: macOS keyboard
- ✅ ⌘ shortcuts work like macOS in every app (⌘C/V/X/Z/A/S/F/T/N/W…), with safe terminal handling (⌘C copies instead of interrupting; ⌘Z can't suspend)
- ✅ ⌘Q quits the whole app (every window); ⌘W closes a tab/window; ⌘H hides; ⌃⌘F full screen; ⌃1–9 switch desktops
- ✅ macOS text navigation: ⌘←/→, ⌘↑/↓, ⌥←/→, ⌘⌫, ⌘[ / ⌘]
- ✅ Liquid Glass popovers refract the real windows behind them, not just the wallpaper

## v1.3: Updates (the foundation)
- ✅ Foxtail ships as packages: `foxtail-desktop` and `foxtail-keyring`
- ✅ Signed pacman repo (`[foxtail]`), built by `scripts/build-repo.sh`; installed systems require valid signatures
- ✅ **Software Update** pane: checks pacman + Flatpak, notifies, installs with one click
- ✅ **Btrfs + snapshots** before and after every update, restorable from System Settings or the boot menu
- [ ] Publish the repo (`scripts/publish-repo.sh`) and build it in GitHub Actions on every tag
- ✅ Per-user files are stubs that load the shared, updated defaults (1.9); settings that must live per user are migrated once at login

## v1.4: Real hardware
- 🟡 NVIDIA: driver on the ISO and kept only on machines with an NVIDIA GPU (Turing / GTX 16-series and newer; older cards aren't supported by the open driver)
- ✅ Hardware rendering everywhere except VirtualBox/VMware (whose 3D drivers can't run the shell)
- ✅ Installer: **language and keyboard** (applied live, so your password uses the right keys)
- ✅ Installer: **install alongside another OS** in free space, sharing its EFI partition; GRUB offers both at startup
- ✅ Installer: **full-disk encryption** (one password at startup)
- ✅ Laptops: battery menu with time remaining, Low Power / Balanced / Performance, Battery settings, low-battery warnings, auto Low Power at 10%
- ✅ zram compressed swap
- ✅ Lid-close setting (sleep, lock, nothing) and macOS-style closed-lid mode with an external display (1.9)
- [ ] Hibernate
- [ ] Wi-Fi during install (only needed for online extras; installs work offline)
- [ ] Test on at least 5 real machines (Intel, AMD, NVIDIA, and one older laptop)

## v1.5: No terminal needed
- ✅ **Displays:** resolution, refresh rate, scale, rotation, mirroring and arrangement, with a 15-second "Keep these settings?" revert; saved per display
- 🟡 **Night Shift:** on now, custom schedule, warmth (hyprsunset); not visible in VMs
- ✅ **Sound:** output and input device pickers in Settings, output picker in Control Center
- 🟡 **Bluetooth:** scanning, pairing, device icons, battery levels, forget (no Bluetooth in the test VM; devices that ask for a PIN aren't supported yet)
- ✅ **Keyboard:** input sources (add, remove, switch from the menu bar or ⌃Space), key repeat
- ✅ **Users & Groups** (add, password, admin, delete, with safety checks), **Date & Time**, **Printers & Scanners** (CUPS + network discovery), **Default Apps**
- ✅ **⌘Tab app switcher** (most recent first), **Mission Control** (F3 / ⌃↑ / three-finger swipe up: live thumbnails, desktops, drag windows between desktops)
- ✅ **Screenshot toolbar (⇧⌘5)** and **screen recording** with a stop button in the menu bar
- ✅ **Clipboard history** (⌥⌘V)
- ✅ The shell restarts itself if it crashes, and locks again if it was locked
- ✅ GTK theme fixes now reach existing users (the theme lives in /usr/share instead of being copied to each account)
- ✅ **More like macOS:**
  - Liquid Glass rebuilt: edges lens what's behind them (Snell's-law refraction over a squircle bevel), clear at the rim and frosted in the middle, a thin light sheen, a tint that adapts so text stays readable, glow on press, and Clear / Tinted styles (macOS 26.1)
  - Files on the desktop (from the Desktop folder): thumbnails, select, drag, rename, New Folder, Get Info, Clean Up, Sort By; clicking the desktop makes Files the front app
  - Screenshots land on the Desktop as "Screenshot … at ….png" with the floating thumbnail; ⌃⇧⌘3/4 copy instead; Save to Desktop / Documents / Pictures / Clipboard
  - Window tiling (Window ▸ Move & Resize, Fill, Center, ⌃⌥ arrows); the green button zooms; ⌘H hides the app, ⌥⌘H hides others; Show Desktop (F11); windows snap to edges
  - Spotlight in the Tahoe style: grouped results with a preview, System Settings panes, and browsing Applications / Files / Actions / Clipboard (⌘1–⌘4)
  - Dock: Downloads stack, full/empty Trash with Empty Trash, notification badges, drag to reorder or out to remove, Options ▸ Open at Login, bounce on attention
  - Hot Corners, Emoji & Symbols (⌃⌘Space), submenus, Apple-menu Recent Items, Finder's Go menu and shortcuts in Files
  - Notification Center widgets (clock, batteries), interface sounds and a startup chime, Auto appearance, Dynamic wallpaper
  - System Settings: Menu Bar, Trackpad and Mouse panes, Login Items, Hot Corners, sound effects
- ✅ **Fewer limitations:** the yellow traffic light minimizes GTK 4 apps; drag and drop between the desktop, Files and the Dock (Trash, Downloads, apps); Finder-style menus for Text Editor, Firefox, Terminal and Calculator; no more pacman "unknown key" warnings
- [ ] Snapping menu on the green button (GTK draws its own buttons; needs a compositor-side menu)
- ✅ Custom keyboard shortcuts: open an app or run a command (1.9)

## v1.6: Polish and public beta
- ✅ **Notifications:** grouped by app in Notification Center (stacks you can expand), the app's action buttons, inline **Reply**, "5m ago" times; banners stay while you hover or type a reply
- ✅ **Qt and KDE apps** use Foxtail's colors, accent, fonts and icons in light and dark mode (qt5ct/qt6ct and kdeglobals)
- ✅ **Accessibility** pane: text size, increase contrast, reduce motion, reduce transparency, zoom (⌥⌘8, ⌥⌘= / ⌥⌘-), screen reader (Orca); passed on to GTK apps too
- ✅ **Translations:** the whole shell in German, French and Spanish (it follows the language chosen in the installer), with localized dates and calendars
- ✅ **Report a Problem…** (Help menu) saves a diagnostics report to the Desktop and opens an issue; the desktop offers to report itself after a crash
- ✅ **Foxtail Guide** in `docs/`: install guide, getting started, troubleshooting, FAQ
- ✅ **Public beta:** issue templates (bug, hardware report, idea), contributing guide, triage labels
- [ ] A testers' channel (Discussions or Matrix)
- 🟡 Foxtail's menus, menu bar, Dock, window buttons and Control Center carry screen-reader names and roles (1.9); not yet tried with Orca

## v1.7: Reliability
- ✅ **CI** (GitHub Actions): QML lint, shell and Lua checks and translation checks on every push; on version tags, an ISO build and a boot test in QEMU (`tests/boot-test.sh`)
- ✅ **Beta updates:** stable and testing update channels, switchable in Software Update
- ✅ **Performance budget** (`tests/perf.sh`): the shell idles at ~0.1% CPU; System Settings, the installer, Launchpad and the capture bar now load only when used (−260 MB)
- [ ] Installer test (an automated install into a VM disk)
- [ ] Animation frame times on integrated GPUs (needs real hardware)

## v1.8: The macOS 27 look
- ✅ **Apps look like Mac apps:** unified toolbars with glass capsule buttons, an edge-to-edge sidebar with accent icons, accent-highlighted menus, macOS-sized controls and 13px text (GTK 4 and libadwaita apps; menus in GTK 3 apps)
- ✅ **Windows:** one 20px continuous corner radius, a hairline edge, a deeper shadow on the active window, glassy traffic lights that work on the first click
- ✅ **Control Center** as one glass panel of modules; **Liquid Glass** with gentler refraction and a Clear-to-Tinted slider
- ✅ **System Settings** with an edge-to-edge sidebar and accent selection; Launchpad is now **Apps**; Firefox gets capsule tabs and address field

## v1.9: Everyday essentials
- ✅ **Custom keyboard shortcuts** (Keyboard settings): open any app or run a command with your own key combination
- ✅ **The lid:** choose what closing it does (sleep, lock, nothing); with an external display connected it only turns off the built-in screen, like macOS
- ✅ **Screen reader labels** for Foxtail's menus, menu bar, Dock, window buttons and Control Center
- ✅ Keyboard shortcuts list and battery status translated; the 13px font reaches GTK 3 settings of existing accounts

## v2.0 “Vixen”: the first major release
- ✅ **Desktop widgets:** Clock, Calendar, Battery, System and Notes on the wallpaper, with a gallery to add and remove them
- ✅ **Setup Assistant** on first login and after major updates: appearance, Liquid Glass, accent color, widgets
- ✅ **Quick Look:** Space in Files previews the selected file
- ✅ **Vixen** wallpapers (day and night) as the new default dynamic wallpaper
- ✅ Polish pass on every screen (1.8–2.0)

## v2.0.1
- ✅ **Liquid Glass, redone:** the glass now lenses what is behind it instead of frosting it (a light blur that keeps shapes readable, stronger refraction at the rim that grows with the size of the glass, a directional edge highlight and a faint contour on the far edge); the Clear/Tinted slider also sets how much it frosts
- ✅ Clicking in a window no longer moves the pointer to the window's center

## Daily driver (next)
- [ ] Runs well on at least 5 real machines (Intel, AMD, NVIDIA, an older laptop), with every 🟡 above confirmed on real hardware
- [ ] Fixed, reliable update cadence
- [ ] Secure Boot support (signed bootloader/kernel)

---

## Known limitations (current)
- **Liquid Glass refraction uses a snapshot.** Menus, Control Center and Spotlight lens a snapshot of the screen taken just before they open (refreshed when windows change), so moving video behind an open menu won't animate in the glass edges (the frosted middle is live). The Dock lenses the wallpaper.
- **Desktop items are on the main display only.**
- **Window tiling uses ⌃⌥ instead of Fn⌃** (PC keyboards don't pass the Fn/Globe key to the system).
- **App menus are written by Foxtail, not read from apps.** Files, Text Editor, Firefox, Terminal and Calculator have their own menus; other apps get a generic File/Edit/View set. Wayland has no global-menu protocol, and GTK 4 apps don't export their menus. ⌘ shortcuts themselves work everywhere.
- **VMs use software rendering.** VirtualBox's 3D driver can't create Qt's EGL surfaces (tested on VirtualBox 7.2), so animations are slower there. Real hardware uses the GPU.
- **The encryption password prompt is plain text.** GRUB asks for it before the boot splash, and unlocking takes a few seconds (GRUB's decryption is slow).
- **Installing alongside needs free space already.** Foxtail doesn't shrink existing partitions; make room first (for example with Windows Disk Management).
