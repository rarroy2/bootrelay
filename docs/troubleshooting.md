# Troubleshooting and warnings

[Back to README](../README.md)

## Troubleshooting

| Symptom | Fix |
|---|---|
| No button appears | Log out and back in. Check `gnome-extensions list` and `journalctl -f -o cat /usr/bin/gnome-shell`. |
| Button appears without an icon | Run `make install-icon`. Keep XML comments out of the SVG; validate it with `gdk-pixbuf`. |
| `pkexec` still asks for a password | Rule not installed, or your user is not in `wheel` (`id`). Re-run `sudo ./install.sh`. |
| `dnf install ./bootrelay-*.rpm` cannot resolve `efibootmgr` or `polkit` | Enable the Fedora repositories and retry. If you used `rpm -i`, use `dnf install ./bootrelay-*.rpm` instead; plain RPM does not resolve dependencies. |
| GRUB fallback says `grub2-reboot` was not found | Install `grub2-tools`, or use the UEFI method. It is only a weak dependency. |
| “No Windows boot entry was detected” | Boot Windows once so firmware creates the entry, check `efibootmgr -v`, or force the entry with `--entry=XXXX`. |
| `BootNext` is written but the machine boots Linux | Firmware ignores `BootNext`. Use `sudo bootrelay --method=grub`, or set the boot order in the firmware setup. |
| `EFI variables are read-only` | `sudo mount -o remount,rw /sys/firmware/efi/efivars` (some firmware exposes them read-only). |
| `GRUB_DEFAULT is '0' but ... requires saved` | Set `GRUB_DEFAULT=saved` in `/etc/default/grub` and regenerate the config. |
| Windows entry missing from GRUB | Fedora disables `os-prober`; this is expected. The UEFI path does not need GRUB. |
| BitLocker asks for the recovery key | Keep your recovery key available. This tool does not change Secure Boot or partitions, but firmware changes can affect BitLocker. |
| NTFS partitions look dirty after returning to Linux | Disable Windows Fast Startup and hibernation in Windows. |

### Useful diagnostics

```bash
bootrelay --detect
bootrelay --list
sudo bootrelay --dry-run
efibootmgr -v
sudo bootrelay --clear
journalctl -t bootrelay --since today
```

---

## Important warnings

- **The button reboots immediately** after the confirmation dialog. Unsaved work
  is lost.
- **BitLocker:** keep the recovery key. The tool does not modify Secure Boot or
  disk layout, but any firmware/boot configuration change can, in rare cases,
  trigger a recovery prompt.
- **Fast Startup / hibernation:** if Windows and Linux share NTFS partitions,
  disable Fast Startup and hibernation in Windows to avoid a dirty filesystem.
- **Firmware bugs:** some UEFI implementations ignore or mishandle `BootNext`.
  The exit code and verification will tell you; use the GRUB fallback instead.
- **No partition writes.** Only `BootNext` (or GRUB `next_entry`) is changed, and
  both are one-shot.
- **Trademark:** “Windows” is a trademark of Microsoft Corporation. The icon is
  an original segmented restart ring and does not use Microsoft artwork. This
  project is not affiliated with or endorsed by Microsoft.

---
