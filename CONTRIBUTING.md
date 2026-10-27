# Contributing to Foxtail

Thanks for helping! Foxtail is in public beta, and the most useful things right now are:

1. **Testing on real hardware.** Install it and file a [hardware report](https://github.com/suhl2DOTxyz/foxtail/issues/new?template=hardware_report.yml), whether it works great or not at all.
2. **Bug reports.** Use **fox menu ▸ Help ▸ Report a Problem…** and attach the report.
3. **Translations.** The shell's strings live in `shell/i18n/<language>.json`; copy `de.json`, translate the values, and open a pull request.

## Working on the code
- The desktop is QML in `shell/` (Quickshell). Copy it to `~/.config/foxtail/shell` on a running Foxtail and run `foxtail-shell`; it reloads on save.
- Window management and shortcuts: `hypr/foxtail.lua` (Hyprland's Lua config).
- Build the ISO: see the [README](README.md#build).

## How issues are sorted
- `needs-triage`: new, not looked at yet
- `bug`, `idea`, `hardware-report`: what kind of issue it is
- `confirmed`: reproduced; `good-first-issue`: a nice place to start
