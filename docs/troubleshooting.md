# Troubleshooting

## Reporting a problem
**fox menu ▸ Help ▸ Report a Problem…** saves a report to your Desktop (system details and logs; nothing personal) and opens a new issue in your browser. Describe what happened and attach the report.

If the menu bar and Dock crash, Foxtail restarts them and offers to report it.

## Common problems

**The USB stick doesn't start.** Use the boot menu (F12 / F11 / Esc) and pick the *UEFI* entry for the stick. Turn off Secure Boot.

**Black screen after the boot logo.** At the boot menu choose **Foxtail (live, safe graphics)**. If that works, please file a [hardware report](https://github.com/suhl2DOTxyz/foxtail/issues/new?template=hardware_report.yml).

**Animations are slow.** In VirtualBox and VMware Foxtail uses software rendering, which is slower. On real hardware, check your graphics card is supported ([install guide](install.md)). Turning off Liquid Glass in Control Center helps on older machines.

**No sound.** Check the output in **Control Center ▸ Sound** or **System Settings ▸ Sound**.

**Wi-Fi network missing.** Some Wi-Fi chips need firmware Foxtail doesn't ship; file a hardware report with your machine's model.

**An update broke something.** Every update takes a snapshot first. Go back to it in **System Settings ▸ Software Update ▸ Snapshots**, or hold **Esc** while the computer starts and choose *Foxtail snapshots*.

**Forgot your password.** Without disk encryption: start from the USB stick, open Terminal and run `sudo arch-chroot` on your Foxtail disk, then `passwd yourname`. With encryption the data can't be recovered.

## Logs
- Desktop shell: `$XDG_RUNTIME_DIR/foxtail-shell.log`; earlier crashes in `~/.local/state/foxtail/crashes`
- System: `journalctl -b -p err`
