# Privileges and security

[Back to README](../README.md)

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
