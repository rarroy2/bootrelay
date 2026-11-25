#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Raúl Arroyo (rarroy2)
#
# bootrelay uninstaller
#
# Removes the extension, the helper and the privilege rule. It does not touch
# boot entries, BootOrder, GRUB or any Windows installation.
#
#   sudo ./uninstall.sh
#
# Options:
#   --dry-run
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

DRY_RUN=0
USER_OVERRIDE=''

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
    printf 'uninstall: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: sudo ./uninstall.sh [OPTIONS]

Options:
  --dry-run       Show what would be removed; change nothing
  --user=NAME     Desktop user whose extension should be removed
  -h, --help      Show this help
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

# Remove a UUID from a list-valued dconf key, preserving the other entries.
gsettings_remove_uuid() {
    local key=$1 uuid=${2:-$EXT_UUID} current inner result='' sep='' item
    local -a items=()

    if ! current=$(run_as_user env "${SESSION_ENV[@]}" \
        gsettings get org.gnome.shell "$key" 2>/dev/null); then
        return 1
    fi

    inner=${current#@as }
    inner=${inner#[}
    inner=${inner%]}

    if [[ -z $inner ]]; then
        return 0
    fi

    local IFS=','
    read -r -a items <<<"$inner"

    for item in "${items[@]}"; do
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        item=${item#\'}
        item=${item%\'}

        if [[ -z $item || $item == "$uuid" ]]; then
            continue
        fi

        result+="$sep'$item'"
        sep=', '
    done

    run_as_user env "${SESSION_ENV[@]}" \
        gsettings set org.gnome.shell "$key" "[$result]"
}

ORIGINAL_ARGS=("$@")

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
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

if (( ! DRY_RUN )) && [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        die 'root privileges are required; install sudo or run as root'
    fi
    say 'Root privileges are required; re-running with sudo...'
    exec sudo -- "$SCRIPT_DIR/uninstall.sh" "${ORIGINAL_ARGS[@]}"
fi

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
SESSION_ENV=(
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID"
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus"
)
EXT_DIR="$TARGET_HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
HICOLOR_ICON="$TARGET_HOME/.local/share/icons/hicolor/scalable/actions/bootrelay-symbolic.svg"
LEGACY_HICOLOR_ICONS=(
    "$TARGET_HOME/.local/share/icons/hicolor/scalable/actions/hello-depression-symbolic.svg"
    "$TARGET_HOME/.local/share/icons/hicolor/scalable/actions/boot-to-windows-symbolic.svg"
)
OLD_EXT_DIR="$TARGET_HOME/.local/share/gnome-shell/extensions/hello-depression@rarroy2.github.io"

say "Removing bootrelay for user: $TARGET_USER"

# Disable first so GNOME Shell does not keep a reference to a deleted extension.
if command -v gnome-extensions >/dev/null 2>&1 && [[ -S /run/user/$TARGET_UID/bus ]]; then
    run_as_user env "${SESSION_ENV[@]}" \
        gnome-extensions disable "$EXT_UUID" 2>/dev/null ||
        warn 'could not disable the extension automatically (it will disappear after logout)'

    if (( ! DRY_RUN )) && command -v gsettings >/dev/null 2>&1; then
        gsettings_remove_uuid enabled-extensions ||
            warn 'could not update the enabled-extensions list'
        gsettings_remove_uuid disabled-extensions ||
            warn 'could not update the disabled-extensions list'
        gsettings_remove_uuid enabled-extensions 'hello-depression@rarroy2.github.io' ||
            warn 'could not update the old enabled-extensions list'
        gsettings_remove_uuid disabled-extensions 'hello-depression@rarroy2.github.io' ||
            warn 'could not update the old disabled-extensions list'
    fi
fi

if [[ -d $EXT_DIR ]]; then
    run rm -rf "$EXT_DIR"
fi

ICON_EXISTS=0
for icon in "$HICOLOR_ICON" "${LEGACY_HICOLOR_ICONS[@]}"; do
    if [[ -f $icon ]]; then
        ICON_EXISTS=1
        run rm -f "$icon"
    fi
done

if [[ -d $OLD_EXT_DIR ]]; then
    run rm -rf "$OLD_EXT_DIR"
fi

for old in /usr/local/bin/boot-to-windows \
    /etc/polkit-1/rules.d/49-hello-depression.rules \
    /etc/sudoers.d/hello-depression; do
    if [[ -e $old ]]; then
        run rm -f "$old"
    fi
done

if [[ -f $HELPER_DST ]]; then
    run rm -f "$HELPER_DST"
fi

if [[ -f $POLKIT_DST ]]; then
    run rm -f "$POLKIT_DST"
fi

if [[ -f $SUDOERS_DST ]]; then
    run rm -f "$SUDOERS_DST"
fi

if (( ICON_EXISTS )) && command -v gtk-update-icon-cache >/dev/null 2>&1 &&
    [[ -f "$TARGET_HOME/.local/share/icons/hicolor/index.theme" ]]; then
    run_as_user gtk-update-icon-cache -f -t "$TARGET_HOME/.local/share/icons/hicolor" ||
        warn 'could not update the user icon cache (not fatal)'
fi

if (( DRY_RUN )); then
    say ''
    say 'Dry run complete; nothing was changed.'
    exit 0
fi

say ''
say 'Removed:'
say "  helper     $HELPER_DST"
say "  extension  $EXT_DIR"
say "  polkit     $POLKIT_DST"
say "  sudoers    $SUDOERS_DST"
say ''
say 'Log out and back in to remove the button from the current session.'
say 'Boot entries and BootOrder were not modified.'
