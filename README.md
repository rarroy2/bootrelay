# Hello Depression

> A GNOME Quick Settings button that reboots straight into Windows on a Fedora dual-boot machine.
>
> Because sometimes you have to go to Windows. And that's depressing.

`hello-depression` adds an **“Ir a Windows”** toggle to the GNOME Quick Settings
grid, next to Wi-Fi, Bluetooth and power. Clicking it asks for confirmation,
configures the *next* boot to Windows, and reboots immediately — no GRUB menu,
no arrow keys, no thinking before coffee.

The project is split into three small, reusable pieces:

1. a root-owned CLI (`boot-to-windows`) that detects Windows and writes the
   one-shot boot selection,
2. a GNOME Shell extension that exposes the button,
3. an installer that wires everything together with a narrow polkit rule.

Nothing is written to your partitions, Windows installation or boot order. Only
the firmware's one-shot `BootNext` variable (or GRUB's `next_entry`) is changed.

---

## Features

- **One-shot only.** The next boot goes to Windows; the following one returns to
  your normal boot order.
- **UEFI first.** Uses `efibootmgr -n XXXX` and verifies `BootNext` before
  rebooting.
- **Handles duplicate/stale entries.** Prefers the entry whose device path points
  to `\EFI\Microsoft\Boot\bootmgfw.efi` over entries that point to a Linux shim
  (a surprisingly common leftover).
- **GRUB fallback.** Works on non-UEFI systems and on firmware that ignores
  `BootNext`, using `grub2-reboot` and verifying `next_entry`.
- **Fails safely.** If no Windows entry is found, or the write cannot be
  verified, it exits without rebooting.
- **No password by default.** A polkit rule allows only the helper binary, only
  for local active users in the `wheel` group. `sudoers` and interactive
  `pkexec` modes are also supported.
- **Interactive-free CLI** with `--detect`, `--list`, `--dry-run` and
  `--no-reboot` for testing.
- **Clean uninstall.** Removes the extension, helper and privilege rule without
  touching boot entries.

---

## Requirements

| Component | Requirement |
|---|---|
| Distribution | Fedora 42–44+ (tested on Fedora 44) |
| Desktop | GNOME Shell 45–50 (tested on 50.6), Wayland or X11 |
| Boot | UEFI recommended; BIOS + GRUB works through the fallback |
| Windows | A UEFI `Windows Boot Manager` entry, or a Windows entry in `grub.cfg` |
| Packages | `efibootmgr`, `polkit` (`pkexec`), `gnome-shell`, `gnome-extensions` |
| GRUB fallback | `grub2-reboot`, `grub2-editenv`, `GRUB_DEFAULT=saved` |

Install the dependencies on Fedora with:

```bash
sudo dnf install efibootmgr polkit
```

---

## Installation

```bash
git clone https://github.com/rarroy2/hello-depression.git
cd hello-depression
sudo ./install.sh
```

Then **log out and log back in**. GNOME Shell does not load a brand-new extension
into the current Wayland session. If the running shell has not scanned the new
folder yet, the installer registers it in the enabled-extensions list so it loads
automatically after the relogin.

After logging in, open Quick Settings (top-right corner) and you will see
**Ir a Windows** in the toggle grid.

### Installer options

| Option | Description |
|---|---|
| `--passwordless=polkit` | Default. Narrow polkit rule; no password prompt. |
| `--passwordless=sudoers` | `sudoers` NOPASSWD rule for `%wheel` instead. |
| `--passwordless=none` | No rule; `pkexec` asks for your password every time. |
| `--no-enable` | Install but do not enable the extension. |
| `--dry-run` | Print every action without changing anything. |
| `--force` | Continue even when no Windows entry is detected. |
| `--user=NAME` | Install the extension for a specific desktop user. |
| `-h`, `--help` | Show help. |

The installer is idempotent: running it again updates the files and replaces the
rule instead of duplicating it.

### Manual extension install

```bash
gnome-extensions install --force dist/hello-depression@rarroy2.github.io.shell-extension.zip
gnome-extensions enable hello-depression@rarroy2.github.io
```

You still need the helper in `/usr/local/bin/boot-to-windows`; use the installer
for that.

### Custom icon

The button and the confirmation dialog use
`extension/icons/hello-depression-symbolic.svg`. Replace it with your own SVG
(monochrome or transparent background) and run:

```bash
make install-icon
```

GNOME reads the copy in `~/.local/share/icons/hicolor/...` before the one inside
the extension directory, so the target updates both locations and refreshes the
icon cache. If the old icon is still cached, log out and back in.

> On Fedora 44 the pixbuf SVG loader rejected an icon that contained an XML
> comment. Keep custom icons free of comments if the button appears without an
> icon.
>
> Symbolic icons are recoloured through their alpha channel. Masks, filters and
> other effects may not survive that process: use explicit paths with
> transparent gaps instead.

---

## Usage

1. Open Quick Settings.
2. Click **Ir a Windows**.
3. Read the confirmation dialog and click **Reiniciar en Windows**.

The confirmation dialog is the only safety net: after confirming, the helper
runs without a password and the machine reboots immediately. Save your work.

Cancel with **Cancelar** or <kbd>Esc</kbd>.

### CLI

The helper can be used without the extension:

```bash
boot-to-windows --detect          # show detected Windows entries (no root)
boot-to-windows --list            # list all UEFI entries and GRUB Windows entries
boot-to-windows --dry-run         # show what would be done (no writes)
sudo boot-to-windows --no-reboot  # set the next boot, do not reboot
sudo boot-to-windows --clear      # clear a pending one-shot selection
sudo boot-to-windows              # set the next boot and reboot now
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
sudo boot-to-windows --clear   # clears BootNext and GRUB next_entry
# or manually:
sudo rm -f /sys/firmware/efi/efivars/BootNext-8be4df61-93ca-11d2-aa0d-00e098032b8c
sudo grub2-editenv - unset next_entry
```

---

## How it works

```text
Quick Settings toggle ("Ir a Windows")
  └─ confirmation dialog
       └─ sudo -n /usr/local/bin/boot-to-windows --reboot --quiet
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

## Privilege model

Writing `BootNext` requires root. The extension tries `sudo -n` first and then
`pkexec`; the installer decides which mechanism is authorized silently.

### Default: polkit rule

`/etc/polkit-1/rules.d/49-hello-depression.rules`:

```js
polkit.addRule(function (action, subject) {
    if (action.id !== 'org.freedesktop.policykit.exec')
        return null;
    if (action.lookup('program') !== '/usr/local/bin/boot-to-windows')
        return null;
    if (!subject.local || !subject.active)
        return null;
    if (!subject.isInGroup('wheel'))
        return null;
    return polkit.Result.YES;
});
```

Scope: one exact binary, local active sessions, `wheel` members only. If the rule
is removed, `pkexec` falls back to asking for a password instead of breaking.

### Alternative: sudoers

```sudoers
%wheel ALL=(root) NOPASSWD: /usr/local/bin/boot-to-windows
```

Installed as `/etc/sudoers.d/hello-depression` (`0440`) after validation with
`visudo -cf`. The extension tries `sudo -n` first and falls back to `pkexec`, so
either privilege mode works without extra configuration.

### Interactive mode

`--passwordless=none` installs no rule. `pkexec` shows the GNOME authentication
dialog every time.

The helper is `root:root 0755`, validates `--entry` as four hex digits against
the real firmware entries, and has no code path that executes arbitrary
commands. That is deliberate: it is designed to be callable as root without a
password.

---

## Uninstall

```bash
sudo ./uninstall.sh
```

This disables and removes the extension, the helper, the icon and both privilege
rules. It does **not** touch `BootNext`, `BootOrder`, GRUB or Windows.

Log out and back in to remove the button from the running session.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| No button appears | Log out and back in. Check `gnome-extensions list` and `journalctl -f -o cat /usr/bin/gnome-shell`. |
| Button appears without an icon | Run `make install-icon`. Keep XML comments out of the SVG; validate it with `gdk-pixbuf`. |
| `pkexec` still asks for a password | Rule not installed, or your user is not in `wheel` (`id`). Re-run `sudo ./install.sh`. |
| “No Windows boot entry was detected” | Boot Windows once so firmware creates the entry, check `efibootmgr -v`, or force the entry with `--entry=XXXX`. |
| `BootNext` is written but the machine boots Linux | Firmware ignores `BootNext`. Use `sudo boot-to-windows --method=grub`, or set the boot order in the firmware setup. |
| `EFI variables are read-only` | `sudo mount -o remount,rw /sys/firmware/efi/efivars` (some firmware exposes them read-only). |
| `GRUB_DEFAULT is '0' but ... requires saved` | Set `GRUB_DEFAULT=saved` in `/etc/default/grub` and regenerate the config. |
| Windows entry missing from GRUB | Fedora disables `os-prober`; this is expected. The UEFI path does not need GRUB. |
| BitLocker asks for the recovery key | Keep your recovery key available. This tool does not change Secure Boot or partitions, but firmware changes can affect BitLocker. |
| NTFS partitions look dirty after returning to Linux | Disable Windows Fast Startup and hibernation in Windows. |

### Useful diagnostics

```bash
boot-to-windows --detect
boot-to-windows --list
sudo boot-to-windows --dry-run
efibootmgr -v
sudo boot-to-windows --clear
journalctl -t boot-to-windows --since today
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

## Development

```bash
make check     # bash -n, JS syntax check, --version/--help
make detect    # run the UEFI detection on this machine
make pack      # build dist/<uuid>.shell-extension.zip
make clean
```

The extension targets the GNOME 45+ ESM APIs:

- `QuickSettings.QuickToggle` with `title`, `subtitle` and `iconName`
- `SystemIndicator` + `Main.panel.statusArea.quickSettings.addExternalIndicator()`
- `ModalDialog` with `addButton({label, action, default, key})`

Tested end-to-end (install → click → reboot into Windows → return to Fedora)
on Fedora 44, GNOME Shell 50.6, Wayland, UEFI.

Project layout:

```text
bin/boot-to-windows                    privileged helper
extension/{metadata.json,extension.js} GNOME Shell extension
extension/icons/                       original segmented restart icon
polkit/49-hello-depression.rules       default passwordless rule
sudoers/hello-depression               alternative rule
install.sh, uninstall.sh               installer and remover
Makefile                               check, detect, pack, clean
```

---

## License

MIT © 2026 Raúl Arroyo ([rarroy2](https://github.com/rarroy2)).

See [LICENSE](LICENSE).
