<p align="center">
  <img src="assets/bootrelay-icon.svg" width="112" alt="BootRelay icon">
</p>

# BootRelay

> A GNOME Quick Settings button that reboots straight into Windows on a Fedora dual-boot machine.
>
> Because sometimes you have to go to Windows. And that's depressing.

**BootRelay** adds an **“Ir a Windows”** toggle to the GNOME Quick Settings
grid, next to Wi-Fi, Bluetooth and power. Clicking it asks for confirmation,
configures the *next* boot to Windows, and reboots immediately — no GRUB menu,
no arrow keys, no thinking before coffee.

The project is split into three small, reusable pieces:

1. a root-owned CLI (`bootrelay`) that detects Windows and writes the
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
| Packages | Hard dependencies: `efibootmgr`, `polkit` (`pkexec`), `gnome-shell`. `gnome-extensions` is part of `gnome-shell`. |
| GRUB fallback | `grub2-tools` (`grub2-reboot`, `grub2-editenv`), `GRUB_DEFAULT=saved` |

With the RPM, `dnf` resolves and installs missing hard dependencies from the
enabled Fedora repositories. You do not need to install them separately. The
manual command below is only for the source installer (or an offline setup):

```bash
sudo dnf install efibootmgr polkit
```

`grub2-tools` is a weak dependency (`Recommends`): `dnf` installs it by default
when available, but it is only needed for the GRUB fallback. The UEFI path does
not use it.

---

## Installation

### Fedora package (RPM)

Install the RPM attached to the release:

```bash
sudo dnf install ./bootrelay-0.3.0-1.fc44.noarch.rpm
```

The package installs the helper at `/usr/bin/bootrelay`, the polkit rule in
`/usr/share/polkit-1/rules.d/`, the extension in
`/usr/share/gnome-shell/extensions/` and the icon in the system icon theme.

`dnf` installs missing hard dependencies (`efibootmgr`, `polkit`, `gnome-shell`)
automatically. Do not install this package with `rpm -i`: plain RPM does not
resolve dependencies.

Log out and back in, then enable the extension if it is not already enabled:

```bash
gnome-extensions enable bootrelay@rarroy2.github.io
```

> If you previously installed with `install.sh`, run `sudo ./uninstall.sh` before
> installing the RPM. The manual polkit rule in `/etc` would otherwise override
> the packaged one, and the per-user extension would shadow the system
> extension.

### From source (installer)

```bash
git clone https://github.com/rarroy2/bootrelay.git
cd bootrelay
sudo ./install.sh
```

Then **log out and log back in**. GNOME Shell does not load a brand-new extension
into the current Wayland session. If the running shell has not scanned the new
folder yet, the installer registers it in the enabled-extensions list so it loads
automatically after the relogin.

After logging in, open Quick Settings (top-right corner) and you will see
**Ir a Windows** in the toggle grid.

### Migrating from hello-depression (0.2.x)

The project was renamed to BootRelay in 0.3.0. The old name is kept only for
migration and compatibility.

- **RPM users:** install the `bootrelay` RPM. Its `Obsoletes` field removes the
  old `hello-depression` package and its system files automatically.
- **Manual installer users:** run the old `sudo ./uninstall.sh` before installing
  BootRelay, or let the new installer clean the old `/usr/local` helper, rules
  and icons.
- After installing, log out and back in, disable or remove
  `hello-depression@rarroy2.github.io`, and enable
  `bootrelay@rarroy2.github.io`.

`/usr/bin/boot-to-windows` remains as a deprecated symlink to
`/usr/bin/bootrelay` in the RPM.

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
gnome-extensions install --force dist/bootrelay@rarroy2.github.io.shell-extension.zip
gnome-extensions enable bootrelay@rarroy2.github.io
```

You still need the helper in `/usr/bin/bootrelay` or
`/usr/local/bin/bootrelay`; use the RPM or the installer for that.

### Custom icon

The button and the confirmation dialog use
`extension/icons/bootrelay-symbolic.svg`. Replace it with your own SVG
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

## Privilege model

Writing `BootNext` requires root. The extension looks for the helper in
`/usr/bin` (RPM) and `/usr/local/bin` (installer), then tries `sudo -n` first and
`pkexec` as a fallback.

### Default: polkit rule

The RPM installs the rule in `/usr/share/polkit-1/rules.d/`; the manual installer
uses `/etc/polkit-1/rules.d/`. Both allow the new helper paths and the deprecated compatibility paths:

```js
polkit.addRule(function (action, subject) {
    if (action.id !== 'org.freedesktop.policykit.exec')
        return null;
    var program = action.lookup('program');
    if (program !== '/usr/bin/bootrelay' &&
        program !== '/usr/local/bin/bootrelay' &&
        program !== '/usr/bin/boot-to-windows' &&
        program !== '/usr/local/bin/boot-to-windows')
        return null;
    if (!subject.local || !subject.active)
        return null;
    if (!subject.isInGroup('wheel'))
        return null;
    return polkit.Result.YES;
});
```

Scope: a narrow set of exact helper paths, local active sessions, `wheel` members only. If the rule
is removed, `pkexec` falls back to asking for a password instead of breaking.

### Alternative: sudoers

```sudoers
%wheel ALL=(root) NOPASSWD: /usr/bin/bootrelay, /usr/local/bin/bootrelay, /usr/bin/boot-to-windows, /usr/local/bin/boot-to-windows
```

Installed as `/etc/sudoers.d/bootrelay` (`0440`) after validation with
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

With the RPM:

```bash
sudo dnf remove bootrelay
```

With the manual installer:

```bash
sudo ./uninstall.sh
```

The RPM removal deletes the system helper, the polkit rule, the system extension
and the icon. The manual uninstaller does the same for the `/usr/local` copy. It
does **not** touch `BootNext`, `BootOrder`, GRUB or Windows.

Log out and back in to remove the button from the running session.

---

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

## Roadmap

- [#1 — Distribution portability and one button per installed OS](https://github.com/rarroy2/bootrelay/issues/1)
- [#2 — Windows client: one-click switch from Windows to Fedora](https://github.com/rarroy2/bootrelay/issues/2)

The current release still exposes a single **Ir a Windows** action. The roadmap
covers testing other distributions and showing every installed OS as its own
Quick Settings entry, plus a Windows client for the reverse direction.

## Development

```bash
make check     # bash -n, JS syntax check, spec parse, --version/--help
make detect    # run the UEFI detection on this machine
make pack      # build dist/<uuid>.shell-extension.zip
make srpm      # build dist/rpmbuild/SRPMS/*.src.rpm
make rpm       # build the noarch RPM in dist/rpmbuild/RPMS/
make rpmlint   # run rpmlint if it is installed
make clean
```

The extension targets the GNOME 45+ ESM APIs:

- `QuickSettings.QuickToggle` with `title`, `subtitle` and `iconName`
- `SystemIndicator` + `Main.panel.statusArea.quickSettings.addExternalIndicator()`
- `ModalDialog` with `addButton({label, action, default, key})`

Tested end-to-end (install → click → reboot into Windows → return to Fedora)
on Fedora 44, GNOME Shell 50.6, Wayland, UEFI, both with the source installer
and with the `bootrelay` RPM.

Project layout:

```text
bin/bootrelay                          privileged helper
extension/{metadata.json,extension.js} GNOME Shell extension
extension/icons/                       original segmented restart icon
assets/                                README icon/badge
packaging/bootrelay.spec               RPM spec
polkit/49-bootrelay.rules              default passwordless rule
sudoers/bootrelay                      alternative rule
install.sh, uninstall.sh               installer and remover
Makefile                               check, detect, pack, rpm, clean
```

---

## License

MIT © 2026 Raúl Arroyo ([rarroy2](https://github.com/rarroy2)).

See [LICENSE](LICENSE).
