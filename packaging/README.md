# Packaging and COPR

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

## Publish to COPR

COPR project: `rarroy2/hello-depression`.

### Web interface

1. Create a Fedora account and sign in at <https://copr.fedorainfracloud.org/>.
2. Create a project named `hello-depression`.
3. Select the `fedora-44-x86_64` chroot (and `fedora-rawhide-x86_64` if desired).
4. Build the SRPM first with `make srpm`.
5. Upload
   `dist/rpmbuild/SRPMS/hello-depression-0.2.0-1.fc44.src.rpm` as a new build.
6. Wait for the build to finish.

### Command line

```bash
sudo dnf install copr-cli

# Save the API token from https://copr.fedorainfracloud.org/api/ in ~/.config/copr
copr-cli create hello-depression --chroot fedora-44-x86_64
copr-cli build hello-depression \
    dist/rpmbuild/SRPMS/hello-depression-0.2.0-1.fc44.src.rpm
```

Do not commit the API token.

## User install

```bash
sudo dnf copr enable rarroy2/hello-depression
sudo dnf install hello-depression
```

Then log out and back in, and enable the extension if needed:

```bash
gnome-extensions enable hello-depression@rarroy2.github.io
```

Remove it with:

```bash
sudo dnf remove hello-depression
```

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
