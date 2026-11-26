# Development and packaging

[Back to README](../README.md)

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

## Roadmap

- [#1 — Distribution portability and one button per installed OS](https://github.com/rarroy2/bootrelay/issues/1)
- [#2 — Windows client: one-click switch from Windows to Fedora](https://github.com/rarroy2/bootrelay/issues/2)

The current release still exposes a single **Ir a Windows** action. The roadmap
covers testing other distributions and showing every installed OS as its own
Quick Settings entry, plus a Windows client for the reverse direction.
