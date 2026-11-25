// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Raúl Arroyo (rarroy2)
//
// BootRelay - GNOME Shell extension
//
// Adds an "Ir a Windows" toggle to the Quick Settings grid. Clicking it opens
// a confirmation dialog; confirming runs the privileged helper and the machine
// reboots into Windows.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {ModalDialog} from 'resource:///org/gnome/shell/ui/modalDialog.js';

const HELPER_CANDIDATES = [
    '/usr/bin/bootrelay',
    '/usr/local/bin/bootrelay',
    '/usr/bin/boot-to-windows',
    '/usr/local/bin/boot-to-windows',
];
const SYMBOLIC_ICON = 'bootrelay-symbolic';
const ICON_FILE = 'icons/bootrelay-symbolic.svg';
const FALLBACK_ICON = 'system-reboot-symbolic';

export default class BootRelayExtension extends Extension {
    enable() {
        this._enabled = true;
        this._running = false;
        this._dialog = null;

        this._icon = this._resolveIcon();
        this._helperPath = this._findHelper();

        this._toggle = new QuickSettings.QuickToggle({
            title: 'Ir a Windows',
            subtitle: 'Reiniciar en Windows',
            ...this._icon,
            // This is an action, not a switch: never stay visually "checked".
            toggleMode: false,
        });
        this._toggle.connectObject('clicked', () => this._onClicked(), this);

        this._indicator = new QuickSettings.SystemIndicator();
        this._indicator.quickSettingsItems.push(this._toggle);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._enabled = false;
        this._running = false;

        if (this._dialog) {
            // close() pops the modal grab; destroy() alone would not.
            this._dialog.close();
            this._dialog = null;
        }

        this._toggle?.disconnectObject(this);
        this._toggle = null;

        if (this._indicator) {
            for (const item of this._indicator.quickSettingsItems)
                item.destroy();
            this._indicator.destroy();
            this._indicator = null;
        }
    }

    _resolveIcon() {
        try {
            const theme = new St.IconTheme();
            if (theme.has_icon(SYMBOLIC_ICON))
                return {iconName: SYMBOLIC_ICON};
        } catch (e) {
            console.debug(`bootrelay: icon theme lookup failed: ${e}`);
        }

        try {
            const iconPath = `${this.path}/${ICON_FILE}`;
            if (Gio.File.new_for_path(iconPath).query_exists(null))
                return {gicon: Gio.icon_new_for_string(iconPath)};
        } catch (e) {
            console.debug(`bootrelay: could not load the bundled icon: ${e}`);
        }

        return {iconName: FALLBACK_ICON};
    }

    _findHelper() {
        for (const path of HELPER_CANDIDATES) {
            if (Gio.File.new_for_path(path).query_exists(null))
                return path;
        }

        // Report the missing helper from _runHelper() instead of failing here,
        // so the extension itself still loads and can show a useful message.
        return HELPER_CANDIDATES[0];
    }

    _onClicked() {
        if (this._running || this._dialog)
            return;

        if (Main.panel.closeQuickSettings)
            Main.panel.closeQuickSettings();

        const dialog = new ModalDialog({styleClass: 'prompt-dialog'});
        this._dialog = dialog;

        const content = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style: 'spacing: 10px;',
        });

        content.add_child(new St.Icon({
            ...this._icon,
            icon_size: 48,
            style_class: 'bootrelay-dialog-icon',
        }));

        const title = new St.Label({
            text: 'Ir a Windows',
            style_class: 'headline',
            x_align: Clutter.ActorAlign.CENTER,
        });

        const body = new St.Label({
            text: 'Se configurará el próximo arranque para Windows y el equipo ' +
                  'se reiniciará inmediatamente.\n\n' +
                  'Guarda tu trabajo antes de continuar.',
            x_align: Clutter.ActorAlign.CENTER,
        });
        body.clutter_text.line_wrap = true;

        content.add_child(title);
        content.add_child(body);
        dialog.contentLayout.add_child(content);

        let confirmed = false;

        dialog.addButton({
            label: 'Cancelar',
            key: Clutter.KEY_Escape,
            action: () => dialog.close(),
        });
        dialog.addButton({
            label: 'Reiniciar en Windows',
            default: true,
            action: () => {
                confirmed = true;
                dialog.close();
            },
        });

        const cleanup = () => {
            if (this._dialog === dialog)
                this._dialog = null;
        };

        dialog.connect('closed', () => {
            cleanup();
            if (confirmed && this._enabled)
                this._runHelper();
        });
        dialog.connect('destroy', cleanup);

        if (!dialog.open()) {
            cleanup();
            dialog.destroy();
            Main.notify('No se pudo ir a Windows',
                'Otro diálogo del sistema está abierto. Inténtalo de nuevo.');
        }
    }

    _runHelper() {
        if (this._running)
            return;

        if (!Gio.File.new_for_path(this._helperPath).query_exists(null)) {
            this._notifyError(
                'No se encontró bootrelay. Instala el paquete ' +
                'bootrelay o ejecuta install.sh.');
            return;
        }

        this._running = true;

        // A sudoers NOPASSWD rule works without any polkit setup. With -n sudo
        // fails immediately (no prompt) when it is not allowed, so falling back
        // to pkexec is safe: polkit either grants silently or asks for a password.
        this._spawnHelper(['sudo', '-n', this._helperPath, '--reboot', '--quiet'],
            result => {
                if (result.ok)
                    return; // The machine is rebooting.

                if (result.spawnFailed || result.status === 1) {
                    this._spawnHelper(['pkexec', this._helperPath, '--reboot', '--quiet'],
                        pkResult => {
                            this._running = false;
                            if (!pkResult.ok && this._enabled) {
                                this._notifyError(pkResult.detail ||
                                    result.detail);
                            }
                        });
                    return;
                }

                this._running = false;
                if (this._enabled)
                    this._notifyError(result.detail);
            });
    }

    _spawnHelper(argv, callback) {
        let proc;

        try {
            proc = Gio.Subprocess.new(argv,
                Gio.SubprocessFlags.STDOUT_PIPE |
                Gio.SubprocessFlags.STDERR_PIPE);
        } catch (e) {
            callback({
                ok: false,
                spawnFailed: true,
                status: -1,
                detail: e.message,
            });
            return;
        }

        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                const [, stdout, stderr] = p.communicate_utf8_finish(res);

                callback({
                    ok: p.get_successful(),
                    spawnFailed: false,
                    status: p.get_exit_status(),
                    detail: (stderr || '').trim() || (stdout || '').trim(),
                });
            } catch (e) {
                callback({
                    ok: false,
                    spawnFailed: true,
                    status: -1,
                    detail: e.message,
                });
            }
        });
    }

    _notifyError(message) {
        Main.notify('No se pudo ir a Windows', message);
    }
}
