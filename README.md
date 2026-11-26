<p align="center">
  <img src="assets/bootrelay-icon.svg" width="112" alt="BootRelay icon">
</p>

# BootRelay

**Relay the next boot to another operating system.**

<p align="center">
  <a href="https://github.com/rarroy2/bootrelay/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/rarroy2/bootrelay?style=flat-square"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/github/license/rarroy2/bootrelay?style=flat-square"></a>
  <img alt="GNOME Shell 45–50" src="https://img.shields.io/badge/GNOME%20Shell-45%E2%80%9350-4A86CF?style=flat-square">
  <img alt="Fedora" src="https://img.shields.io/badge/Fedora-44-51A2DA?logo=fedora&logoColor=white&style=flat-square">
</p>

<p align="center">
  <img src="assets/languages.svg" width="560" alt="Languages: Shell 80.5%, JavaScript 14.8%, Makefile 4.7%">
</p>

BootRelay adds an **Ir a Windows** toggle to the GNOME Quick Settings grid. It
sets a one-shot UEFI `BootNext` entry (or a GRUB `next_entry`), verifies it, and
reboots. It never changes partitions or the permanent boot order.

> Currently switches to Windows only. Multi-OS support is on the
> [roadmap](docs/development.md#roadmap).
>
> The button reboots immediately after confirmation. Save your work and keep
> your BitLocker recovery key available.

## Quick install

### Fedora RPM

```bash
sudo dnf install ./bootrelay-0.3.0-1.fc44.noarch.rpm
```

`dnf` resolves the hard dependencies (`efibootmgr`, `polkit`, `gnome-shell`).
Do not use `rpm -i`. Log out and back in after installing.

### From source

```bash
git clone https://github.com/rarroy2/bootrelay.git
cd bootrelay
sudo ./install.sh
```

## Usage

1. Open Quick Settings.
2. Click **Ir a Windows**.
3. Confirm.

Or use the CLI:

```bash
bootrelay --detect
sudo bootrelay --no-reboot
sudo bootrelay --clear
```

## Features

- One-shot boot: UEFI `BootNext` with a verified GRUB fallback.
- Prefers `bootmgfw.efi` over stale shim entries; validates before rebooting.
- No password by default via a narrow polkit rule; `sudoers` and interactive
  modes are available.
- Fails without rebooting when detection or verification fails.
- GNOME Shell 45–50, Wayland or X11; no partition or `BootOrder` changes.

## Documentation

- [Installation](docs/installation.md)
- [Usage and how it works](docs/usage.md)
- [Privileges and security](docs/security.md)
- [Troubleshooting and warnings](docs/troubleshooting.md)
- [Development and packaging](docs/development.md)

## Migrating from hello-depression

The project was renamed to BootRelay in 0.3.0. The new RPM obsoletes
`hello-depression`; after installing, log out/in and enable
`bootrelay@rarroy2.github.io`. See the
[installation guide](docs/installation.md) for the full migration steps.

## Roadmap

- [#1 — Distribution portability and one button per installed OS](https://github.com/rarroy2/bootrelay/issues/1)
- [#2 — Windows client: one-click switch from Windows to Fedora](https://github.com/rarroy2/bootrelay/issues/2)

## License

MIT © 2026 Raúl Arroyo ([rarroy2](https://github.com/rarroy2)). See
[LICENSE](LICENSE).

“Windows” is a trademark of Microsoft Corporation. BootRelay is not affiliated
with or endorsed by Microsoft.
