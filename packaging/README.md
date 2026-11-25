# Packaging

The RPM is a `noarch` package that installs the helper, the polkit rule, the
GNOME Shell extension and the icon system-wide.

## Build locally

```bash
make rpm
```

Outputs:

```text
dist/rpmbuild/RPMS/noarch/hello-depression-0.2.0-1.fc44.noarch.rpm
dist/rpmbuild/SRPMS/hello-depression-0.2.0-1.fc44.src.rpm
```

`make srpm` only builds the source RPM. `make rpmlint` runs `rpmlint` when it is
installed.

The spec lives in `packaging/hello-depression.spec`. The source tarball is
generated from the working tree, excluding `.git` and `dist`.

## Install the local RPM

```bash
sudo dnf install ./dist/rpmbuild/RPMS/noarch/hello-depression-0.2.0-1.fc44.noarch.rpm
```

`dnf` installs missing hard dependencies (`efibootmgr`, `polkit`, `gnome-shell`)
automatically. Do not use `rpm -i`; plain RPM does not resolve dependencies.

Then log out and back in, and enable the extension if needed:

```bash
gnome-extensions enable hello-depression@rarroy2.github.io
```

Remove it with:

```bash
sudo dnf remove hello-depression
```

The RPM and SRPM are attached to the GitHub release. No RPM repository is
currently published.

## Version bumps

Update the version in all three places before tagging:

- `bin/boot-to-windows` (`VERSION`)
- `packaging/hello-depression.spec` (`Version`, `%changelog`)
- `Makefile` (`VERSION`)

Then rebuild, test, tag and attach the RPM, SRPM and extension ZIP to the GitHub
release.

## Security review notes

The package grants passwordless root access to `/usr/bin/boot-to-windows` for
members of `wheel` in local active sessions. The helper is root-owned, validates
its arguments, never executes arbitrary commands, and only writes the one-shot
`BootNext` variable or GRUB's `next_entry`. This scope is intentional and should
be documented in any future Fedora package review.
