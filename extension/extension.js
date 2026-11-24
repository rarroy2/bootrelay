// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Raúl Arroyo (rarroy2)
//
// Hello Depression - GNOME Shell extension
//
// Adds an "Ir a Windows" toggle to the Quick Settings grid. Clicking it opens
// a confirmation dialog; confirming runs the privileged helper through pkexec
// and the machine reboots into Windows.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {ModalDialog} from 'resource:///org/gnome/shell/ui/modalDialog.js';

const HELPER_PATH = '/usr/local/bin/boot-to-windows';
const SYMBOLIC_ICON = 'boot-to-windows-symbolic';
const FALLBACK_ICON = 'system-reboot-symbolic';

export default class HelloDepressionExtension extends Extension {
    enable() {
        this._enabled = true;
        this._running = false;
        this._dialog = null;

        this._iconName = this._resolveIcon();

        this._toggle = new QuickSettings.QuickToggle({
            title: 'Ir a Windows',
            subtitle: 'Reiniciar en Windows',
            iconName: this._iconName,
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
            const theme = St.IconTheme.get_default();
            const iconDir = `${this.path}/icons`;

            if (!theme.get_search_path().includes(iconDir))
                theme.append_search_path(iconDir);

            if (theme.has_icon(SYMBOLIC_ICON))
                return SYMBOLIC_ICON;
        } catch (e) {
            console.debug(`hello-depression: could not set up the icon theme: ${e}`);
        }

        return FALLBACK_ICON;
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
            spacing: 10,
        });

        content.add_child(new St.Icon({
            iconName: this._iconName,
            icon_size: 48,
            style_class: 'hello-depression-dialog-icon',
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
        this._running = true;

        let proc;
        try {
            proc = Gio.Subprocess.new(
                ['pkexec', HELPER_PATH, '--reboot', '--quiet'],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
        } catch (e) {
            this._running = false;
            this._notifyError(e.message);
            return;
        }

        proc.communicate_utf8_async(null, null, (p, res) => {
            this._running = false;

            if (!this._enabled)
                return;

            try {
                const [, stdout, stderr] = p.communicate_utf8_finish(res);

                if (p.get_successful())
                    return; // The machine is rebooting.

                const detail = (stderr || '').trim() || (stdout || '').trim();
                this._notifyError(detail ||
                    `boot-to-windows terminó con estado ${p.get_exit_status()}`);
            } catch (e) {
                this._notifyError(e.message);
            }
        });
    }

    _notifyError(message) {
        Main.notify('No se pudo ir a Windows', message);
    }
}
