# FAQ

**Is Foxtail macOS?** No. Foxtail is Linux (Arch) with a desktop designed to look and work like a Mac. It runs Linux apps, not Mac apps, and has nothing to do with Apple.

**Can I run Windows or Mac apps?** Mac apps, no. Many Windows apps and games run through Steam (Proton) or Bottles from the App Store.

**Where do I get apps?** The **App Store** in the fox menu (Flatpak, from Flathub). Arch packages work too, with `pacman` in the Terminal.

**Will my files be safe when I update?** Updates take a Btrfs snapshot before and after, so you can go back. Your files in your home folder aren't touched by updates.

**What's Liquid Glass?** Foxtail's take on Apple's material from macOS 26 "Tahoe": glass that bends what's behind it. Turn it off in Control Center, or choose *Tinted* in **System Settings ▸ Appearance**.

**Why does it ask for the disk password before the logo?** With encryption on, the boot loader unlocks the disk before Foxtail starts.

**Is it stable?** Not yet: Foxtail is in beta until **2.0**. See the [roadmap](../ROADMAP.md).

**How can I help?** Use it and report what breaks, or file a [hardware report](https://github.com/suhl2DOTxyz/foxtail/issues/new?template=hardware_report.yml) for your computer. Code contributions: see [CONTRIBUTING](../CONTRIBUTING.md).
