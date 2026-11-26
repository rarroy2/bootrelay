# Usage and how it works

[Back to README](../README.md)

## Quick start

1. Open Quick Settings.
2. Click **Ir a Windows**.
3. Read the confirmation dialog and click **Reiniciar en Windows**.

The confirmation dialog is the only safety net: after confirming, the helper
runs without a password and the machine reboots immediately. Save your work.

Cancel with **Cancelar** or <kbd>Esc</kbd>.

## CLI

The helper can be used without the extension:

```bash
bootrelay --detect          # show detected Windows entries (no root)
bootrelay --list            # list all UEFI entries and GRUB Windows entries
bootrelay --dry-run         # show what would be done (no writes)
sudo bootrelay --no-reboot  # set the next boot, do not reboot
sudo bootrelay --clear      # clear a pending one-shot selection
sudo bootrelay              # set the next boot and reboot now
```

| Flag | Description |
|---|---|
| `--detect` | Detect Windows and exit. Exit code 3 if nothing was found. |
| `--list` | List every UEFI entry (with score) and every GRUB Windows entry. |
| `--dry-run` | Print the exact commands that would run. No writes, no reboot. |
| `--no-reboot` | Write and verify the boot selection, then stop. |
| `--clear` | Clear a pending `BootNext` / GRUB `next_entry` and exit. |
| `--method=auto\|uefi\|grub` | Force a backend. Default: `auto`. |
| `--entry=XXXX` | Force a specific UEFI entry, e.g. `--entry=0005`. |
| `--escalate=auto\|pkexec\|sudo\|none` | How to obtain root when not already root. |
| `--quiet`, `-q` | Only print errors. Used by the extension. |
| `--version`, `-V` | Print version. |
| `--help`, `-h` | Print help. |

Exit codes:

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Usage or generic error |
| `2` | Permission / escalation error |
| `3` | No Windows boot entry found |
| `4` | Failed to write or verify the boot selection |
| `5` | Unsupported system or configuration |
| `6` | EFI variables are read-only |

To undo a test without rebooting:

```bash
sudo bootrelay --clear   # clears BootNext and GRUB next_entry
# or manually:
sudo rm -f /sys/firmware/efi/efivars/BootNext-8be4df61-93ca-11d2-aa0d-00e098032b8c
sudo grub2-editenv - unset next_entry
```

---

## How it works

```text
Quick Settings toggle ("Ir a Windows")
  └─ confirmation dialog
       └─ sudo -n bootrelay --reboot --quiet
            │   (falls back to pkexec when sudo is not authorized)
            ├─ efibootmgr -n 0005        (UEFI: one-shot BootNext)
            │    └─ verify BootNext == 0005
            │         └─ systemctl reboot
            └─ grub2-reboot "Windows..." (fallback: one-shot next_entry)
                 └─ verify next_entry
                      └─ systemctl reboot
```

If the primary backend fails and `--method=auto` is in use, the helper tries the
GRUB fallback before giving up. If neither works, it exits without rebooting.

### UEFI detection and scoring

The helper parses `efibootmgr -v` and scores each entry:

| Signal | Score |
|---|---|
| Device path contains `bootmgfw.efi` (real Windows loader) | +100 |
| Label is exactly `Windows Boot Manager` | +50 |
| Label contains `windows` | +30 |
| Device path points to a shim/GRUB/Fedora loader (stale entry) | −80 |
| Entry is active | +5 |

Only entries with a positive score are candidates. This matters on machines with
leftovers like:

```text
Boot0000* Windows Boot Manager  -> \EFI\FEDORA\SHIMX64.EFI      score 5
Boot0005* Windows Boot Manager  -> \EFI\MICROSOFT\BOOT\BOOTMGFW.EFI  score 185
```

Naive scripts pick `Boot0000` and boot Linux again. This one picks `Boot0005`.

If two real Windows entries tie, the helper warns and picks the first; override it
with `--entry=XXXX`.

### GRUB fallback

Parses `menuentry` and `submenu` blocks from `/boot/grub2/grub.cfg`,
`/boot/grub/grub.cfg` and `/boot/efi/EFI/fedora/grub.cfg`, matching titles that
contain `windows`. Nested entries are passed to `grub2-reboot` as
`Parent>Child`. The write is verified through `grub2-editenv list`.

`GRUB_DEFAULT` must be `saved` for `next_entry` to be honoured. The helper
refuses to continue when it can read a different value.

> Fedora disables `os-prober` by default, so many systems have no Windows entry
> in GRUB at all. That is fine: the UEFI path is the primary one.

---
