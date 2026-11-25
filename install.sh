#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Raúl Arroyo (rarroy2)
#
# bootrelay installer
#
# Installs the bootrelay helper, the GNOME Shell extension and (by
# default) a narrowly scoped polkit rule so the Quick Settings button can
# reboot into Windows without a password prompt.
#
# Run it from your desktop session:
#   sudo ./install.sh
#
# Options:
#   --passwordless=polkit|sudoers|none
#   --no-enable
#   --dry-run
#   --force
#   --user=NAME

set -euo pipefail

export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 022

readonly EXT_UUID='bootrelay@rarroy2.github.io'
readonly HELPER_DST='/usr/local/bin/bootrelay'
readonly POLKIT_DST='/etc/polkit-1/rules.d/49-bootrelay.rules'
readonly SUDOERS_DST='/etc/sudoers.d/bootrelay'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly SCRIPT_DIR
readonly HELPER_SRC="$SCRIPT_DIR/bin/bootrelay"
readonly POLKIT_SRC="$SCRIPT_DIR/polkit/49-bootrelay.rules"
readonly SUDOERS_SRC="$SCRIPT_DIR/sudoers/bootrelay"
readonly EXT_SRC="$SCRIPT_DIR/extension"
readonly ICON_SRC="$EXT_SRC/icons/bootrelay-symbolic.svg"

PASSWORDLESS='polkit'
DO_ENABLE=1
DRY_RUN=0
FORCE=0
USER_OVERRIDE=''

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
    printf 'install: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: sudo ./install.sh [OPTIONS]

Options:
  --passwordless=polkit   Install a polkit rule (default, no password prompt)
  --passwordless=sudoers  Use a sudoers NOPASSWD rule instead
  --passwordless=none     Do not install any privilege rule (pkexec will ask)
  --no-enable             Install the extension but do not enable it
  --dry-run               Show what would be done; change nothing
  --force                 Continue even if no Windows entry is detected
  --user=NAME             Desktop user to install the extension for
  -h, --help              Show this help

Run this script with sudo from the user session that runs GNOME.
EOF
}

run() {
    if (( DRY_RUN )); then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

run_as_user() {
    if (( DRY_RUN )); then
        printf '[dry-run] runuser -u %s --' "$TARGET_USER"
        printf ' %q' "$@"
        printf '\n'
    else
        runuser -u "$TARGET_USER" -- "$@"
    fi
}

# Fallback used when the extension was copied after the current shell session
# started: the running shell has not scanned it yet, so gnome-extensions cannot
# enable it. Adding it to the dconf list makes it load on the next login.
enable_extension_via_gsettings() {
    local current inner value

    if ! current=$(run_as_user env "${SESSION_ENV[@]}" \
        gsettings get org.gnome.shell enabled-extensions 2>/dev/null); then
        return 1
    fi

    inner=${current#@as }
    inner=${inner#[}
    inner=${inner%]}

    if [[ $inner == *"'$EXT_UUID'"* ]]; then
        return 0
    fi

    if [[ -n $inner ]]; then
        value="[$inner, '$EXT_UUID']"
    else
        value="['$EXT_UUID']"
    fi

    run_as_user env "${SESSION_ENV[@]}" \
        gsettings set org.gnome.shell enabled-extensions "$value"
}

TEMP_FILE=''
cleanup() {
    if [[ -n $TEMP_FILE ]]; then
        rm -f "$TEMP_FILE"
    fi
}
trap cleanup EXIT

ORIGINAL_ARGS=("$@")

while (($#)); do
    case "$1" in
        --passwordless=*) PASSWORDLESS=${1#*=} ;;
        --passwordless)
            shift
            (($#)) || die '--passwordless requires a value'
            PASSWORDLESS=$1
            ;;
        --no-enable) DO_ENABLE=0 ;;
        --dry-run) DRY_RUN=1 ;;
        --force) FORCE=1 ;;
        --user=*) USER_OVERRIDE=${1#*=} ;;
        --user)
            shift
            (($#)) || die '--user requires a value'
            USER_OVERRIDE=$1
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1 (try --help)"
            ;;
    esac
    shift
done

case "$PASSWORDLESS" in
    polkit | sudoers | none) ;;
    *) die "invalid --passwordless value: $PASSWORDLESS" ;;
esac

# ---------------------------------------------------------------------------
# Privilege escalation
# ---------------------------------------------------------------------------

if (( ! DRY_RUN )) && [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        die 'root privileges are required; install sudo or run as root'
    fi
    say 'Root privileges are required; re-running with sudo...'
    exec sudo -- "$SCRIPT_DIR/install.sh" "${ORIGINAL_ARGS[@]}"
fi

# ---------------------------------------------------------------------------
# Resolve the desktop user
# ---------------------------------------------------------------------------

if [[ -n $USER_OVERRIDE ]]; then
    TARGET_USER=$USER_OVERRIDE
elif [[ -n ${SUDO_USER:-} && ${SUDO_USER} != 'root' ]]; then
    TARGET_USER=$SUDO_USER
elif [[ -n ${PKEXEC_UID:-} ]]; then
    TARGET_USER=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
else
    TARGET_USER=$(id -un)
fi

if [[ -z ${TARGET_USER:-} || $TARGET_USER == 'root' ]]; then
    die 'could not determine the desktop user; pass --user=NAME'
fi

if ! getent passwd "$TARGET_USER" >/dev/null 2>&1; then
    die "user '$TARGET_USER' does not exist"
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GROUP=$(id -gn "$TARGET_USER")
SESSION_ENV=(
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID"
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus"
)

if [[ ! -d $TARGET_HOME ]]; then
    die "home directory '$TARGET_HOME' does not exist"
fi

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

for cmd in install getent sed grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "required command not found: $cmd"
    fi
done

for src in "$HELPER_SRC" "$EXT_SRC/metadata.json" "$EXT_SRC/extension.js" \
    "$ICON_SRC" "$POLKIT_SRC" "$SUDOERS_SRC"; do
    if [[ ! -f $src ]]; then
        die "missing source file: $src"
    fi
done

if ! grep -q '^ID=fedora' /etc/os-release 2>/dev/null; then
    warn 'this project is tested on Fedora; continuing on a different distribution'
fi

if ! command -v efibootmgr >/dev/null 2>&1; then
    warn 'efibootmgr is not installed; the UEFI method will not work (dnf install efibootmgr)'
fi

if ! command -v pkexec >/dev/null 2>&1; then
    warn 'pkexec is not installed; the Quick Settings button will not work (dnf install polkit)'
fi

if ! command -v gnome-shell >/dev/null 2>&1; then
    warn 'gnome-shell was not found; the extension will not load'
else
    shell_version=$(gnome-shell --version 2>/dev/null | awk '{print $NF}' | cut -d. -f1)
    if [[ $shell_version =~ ^[0-9]+$ ]] && (( shell_version < 45 )); then
        warn "GNOME Shell $shell_version is older than the supported 45"
    fi
fi

if [[ ! -d /sys/firmware/efi ]]; then
    warn 'this system does not appear to be UEFI; the GRUB fallback will be used'
fi

if command -v bash >/dev/null 2>&1; then
    if ! bash "$HELPER_SRC" --detect --quiet; then
        if (( FORCE )); then
            warn 'no Windows boot entry was detected; continuing because of --force'
        elif (( DRY_RUN )); then
            warn 'no Windows boot entry was detected (dry run; continuing)'
        else
            die 'no Windows boot entry was detected. Boot Windows once, or re-run with --force'
        fi
    fi
fi

if (( ! DRY_RUN )) && [[ $PASSWORDLESS == 'sudoers' ]] && ! command -v visudo >/dev/null 2>&1; then
    die 'visudo was not found; install the sudo package or use --passwordless=polkit'
fi

if (( ! DRY_RUN )) && [[ $PASSWORDLESS == 'polkit' ]] && ! systemctl is-active --quiet polkit 2>/dev/null; then
    warn 'polkit does not look active; the passwordless rule may not be applied'
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

say "Installing for user: $TARGET_USER ($TARGET_HOME)"
say "Privilege mode: $PASSWORDLESS"

# 1. Helper
run install -o root -g root -m 0755 "$HELPER_SRC" "$HELPER_DST"

# Deprecated compatibility name for the 0.2.x release.
run ln -sfn "$HELPER_DST" /usr/local/bin/boot-to-windows

# 2. Privilege rule
case "$PASSWORDLESS" in
    polkit)
        run install -d -o root -g root -m 0755 /etc/polkit-1/rules.d
        run install -o root -g root -m 0644 "$POLKIT_SRC" "$POLKIT_DST"
        if [[ -f $SUDOERS_DST ]]; then
            run rm -f "$SUDOERS_DST"
        fi
        if (( ! DRY_RUN )); then
            say 'Polkit rule installed (it is picked up automatically).'
        fi
        ;;
    sudoers)
        TEMP_FILE=$(mktemp)
        cp "$SUDOERS_SRC" "$TEMP_FILE"
        if ! visudo -cf "$TEMP_FILE" >/dev/null; then
            die 'the sudoers template failed validation'
        fi
        run install -o root -g root -m 0440 "$TEMP_FILE" "$SUDOERS_DST"
        if [[ -f $POLKIT_DST ]]; then
            run rm -f "$POLKIT_DST"
        fi
        if (( ! DRY_RUN )); then
            say 'Sudoers rule installed and validated with visudo.'
        fi
        ;;
    none)
        if [[ -f $POLKIT_DST ]]; then
            run rm -f "$POLKIT_DST"
        fi
        if [[ -f $SUDOERS_DST ]]; then
            run rm -f "$SUDOERS_DST"
        fi
        if (( ! DRY_RUN )); then
            say 'No privilege rule installed; pkexec will ask for a password.'
        fi
        ;;
esac

# 3. Extension (as the desktop user)
EXT_DIR="$TARGET_HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
HICOLOR_DIR="$TARGET_HOME/.local/share/icons/hicolor/scalable/actions"

if ! command -v runuser >/dev/null 2>&1; then
    die 'runuser was not found (util-linux); cannot install files as the desktop user'
fi

# Create the directory tree as the user so parents get the right ownership.
run_as_user mkdir -p "$EXT_DIR/icons" "$HICOLOR_DIR"

run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0644 \
    "$EXT_SRC/metadata.json" "$EXT_DIR/metadata.json"
run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0644 \
    "$EXT_SRC/extension.js" "$EXT_DIR/extension.js"
run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0644 \
    "$ICON_SRC" "$EXT_DIR/icons/bootrelay-symbolic.svg"
run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0644 \
    "$ICON_SRC" "$HICOLOR_DIR/bootrelay-symbolic.svg"

# Clean up names from 0.1.x, 0.2.x and the old project name.
run rm -f "$EXT_DIR/icons/boot-to-windows-symbolic.svg" \
    "$EXT_DIR/icons/hello-depression-symbolic.svg" \
    "$HICOLOR_DIR/boot-to-windows-symbolic.svg" \
    "$HICOLOR_DIR/hello-depression-symbolic.svg"
run rm -f /etc/polkit-1/rules.d/49-hello-depression.rules \
    /etc/sudoers.d/hello-depression
OLD_EXT_DIR="$TARGET_HOME/.local/share/gnome-shell/extensions/hello-depression@rarroy2.github.io"
if [[ -d $OLD_EXT_DIR ]]; then
    run rm -rf "$OLD_EXT_DIR"
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1 &&
    [[ -f "$TARGET_HOME/.local/share/icons/hicolor/index.theme" ]]; then
    run_as_user gtk-update-icon-cache -f -t "$TARGET_HOME/.local/share/icons/hicolor" ||
        warn 'could not update the user icon cache (not fatal)'
fi

# 4. Enable
if (( DO_ENABLE )); then
    if (( ! DRY_RUN )) && [[ ! -S /run/user/$TARGET_UID/bus ]]; then
        warn "no session bus for $TARGET_USER; enable later with:"
        warn "  gnome-extensions enable $EXT_UUID"
    else
        if run_as_user env "${SESSION_ENV[@]}" \
            gnome-extensions enable "$EXT_UUID" 2>/dev/null; then
            if (( ! DRY_RUN )); then
                say 'Extension enabled.'
            fi
        elif enable_extension_via_gsettings; then
            if (( ! DRY_RUN )); then
                say 'Extension added to the enabled list; it will load after you log back in.'
            fi
        else
            warn 'could not enable the extension automatically; run after logging in:'
            warn "  gnome-extensions enable $EXT_UUID"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if (( DRY_RUN )); then
    say ''
    say 'Dry run complete; nothing was changed.'
    exit 0
fi

say ''
say 'Installed:'
say "  helper     $HELPER_DST"
say "  extension  $EXT_DIR"
case "$PASSWORDLESS" in
    polkit) say "  polkit     $POLKIT_DST" ;;
    sudoers) say "  sudoers    $SUDOERS_DST" ;;
    none) say '  privilege  none (pkexec prompts)' ;;
esac
say ''
say 'Next steps:'
say '  1. Log out and back in. On Wayland a new session is required to load'
say '     the extension for the first time.'
say '  2. Open Quick Settings and click "Ir a Windows".'
say '  3. To diagnose detection: bootrelay --list'
say ''
say 'Warning: the button reboots immediately after confirmation. Save your work.'
