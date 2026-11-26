# Installation

[Back to README](../README.md)

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

## Fedora package (RPM)

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

## From source (installer)

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

## Migrating from hello-depression (0.2.x)

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

## Installer options

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

## Manual extension install

```bash
gnome-extensions install --force dist/bootrelay@rarroy2.github.io.shell-extension.zip
gnome-extensions enable bootrelay@rarroy2.github.io
```

You still need the helper in `/usr/bin/bootrelay` or
`/usr/local/bin/bootrelay`; use the RPM or the installer for that.

## Custom icon

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
