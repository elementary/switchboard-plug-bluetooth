// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Bluetooth.DeviceRow : Gtk.ListBoxRow {
    public Services.Device device { get; construct; }
    public unowned Services.Adapter adapter { get; construct; }
    private static Gtk.SizeGroup size_group;

    private enum Status {
        CONNECTED,
        CONNECTING,
        DISCONNECTING,
        NOT_CONNECTED,
        UNABLE_TO_CONNECT;

        public string to_string () {
            switch (this) {
                case CONNECTED:
                    return _("Connected");
                case CONNECTING:
                    return _("Connecting…");
                case DISCONNECTING:
                    return _("Disconnecting…");
                case UNABLE_TO_CONNECT:
                    return _("Unable to Connnect");
                default:
                    return _("Not Connected");
            }
        }
    }

    private Gtk.Button connect_button;
    private Gtk.Image state;
    private Gtk.Label state_label;

    public DeviceRow (Services.Device device, Services.Adapter adapter) {
        Object (device: device, adapter: adapter);
    }

    static construct {
        size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
    }

    construct {
        var image = new Gtk.Image.from_icon_name (device.icon ?? "bluetooth", Gtk.IconSize.DND);

        state = new Gtk.Image.from_icon_name ("user-offline", Gtk.IconSize.MENU);
        state.halign = Gtk.Align.END;
        state.valign = Gtk.Align.END;

        state_label = new Gtk.Label (null);
        state_label.xalign = 0;
        state_label.use_markup = true;

        var overlay = new Gtk.Overlay ();
        overlay.tooltip_text = device.address;
        overlay.add (image);
        overlay.add_overlay (state);

        var label = new Gtk.Label (device.name ?? device.address);
        label.ellipsize = Pango.EllipsizeMode.END;
        label.hexpand = true;
        label.xalign = 0;

        var settings_button = new Gtk.LinkButton ("settings://network/share/bluetooth");
        settings_button.always_show_image = true;
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-horizontal-symbolic", Gtk.IconSize.MENU);
        settings_button.label = null;
        settings_button.margin_end = 3;
        settings_button.tooltip_text = _("Sharing Settings");

        connect_button = new Gtk.Button ();
        connect_button.valign = Gtk.Align.CENTER;
        size_group.add_widget (connect_button);

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.column_spacing = 6;
        grid.orientation = Gtk.Orientation.HORIZONTAL;
        grid.attach (overlay, 0, 0, 1, 2);
        grid.attach (label, 1, 0, 1, 1);
        grid.attach (state_label, 1, 1, 1, 1);
        grid.attach (settings_button, 2, 0, 1, 2);
        grid.attach (connect_button, 3, 0, 1, 2);

        add (grid);
        show_all ();

        switch (device.icon) {
            case "audio-card":
                settings_button.uri = "settings://sound";
                settings_button.tooltip_text = _("Sound Settings");
                break;
            case "input-gaming":
            case "input-keyboard":
                settings_button.uri = "settings://input/keyboard";
                settings_button.tooltip_text = _("Keyboard Settings");
                break;
            case "input-mouse":
                settings_button.uri = "settings://input/mouse";
                settings_button.tooltip_text = _("Mouse & Touchpad Settings");
                break;
            case "input-tablet":
                settings_button.uri = "settings://input/wacom";
                settings_button.tooltip_text = _("Drawing Tablet Settings");
                break;
            case "printer":
                settings_button.uri = "settings://printer";
                settings_button.tooltip_text = _("Printer Settings");
                break;
        }

        if (device.connected) {
            set_status (Status.CONNECTED);
        } else {
            set_status (Status.NOT_CONNECTED);
        }

        set_sensitive (adapter.powered);

        (adapter as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var powered = changed.lookup_value ("Powered", new VariantType ("b"));
            if (powered != null) {
                set_sensitive (adapter.powered);
            }
        });

        (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var connected = changed.lookup_value ("Connected", new VariantType ("b"));
            if (connected != null) {
                if (device.connected) {
                    set_status (Status.CONNECTED);
                } else {
                    set_status (Status.NOT_CONNECTED);
                }
            }

            var name = changed.lookup_value ("Name", new VariantType ("s"));
            if (name != null) {
                label.label = device.name;
            }

            var icon = changed.lookup_value ("Icon", new VariantType ("s"));
            if (icon != null) {
                image.icon_name = device.icon;
            }
        });

        connect_button.clicked.connect (() => {
            if (!device.connected) {
                set_status (Status.CONNECTING);
                new Thread<void*> (null, () => {
                    try {
                        device.connect ();
                    } catch (Error e) {
                        set_status (Status.UNABLE_TO_CONNECT);
                        critical (e.message);
                    }
                    return null;
                });
            } else {
                set_status (Status.DISCONNECTING);
                new Thread<void*> (null, () => {
                    try {
                        device.disconnect ();
                    } catch (Error e) {
                        state.icon_name = "user-busy";
                        critical (e.message);
                    }
                    return null;
                });
            }
        });
    }

    private void set_status (Status status) {
        state_label.label = GLib.Markup.printf_escaped ("<span font_size='small'>%s</span>", status.to_string ());

        switch (status) {
            case Status.CONNECTED:
                connect_button.label = _("Disconnect");
                connect_button.sensitive = true;
                state.icon_name = "user-available";
                break;
            case Status.CONNECTING:
                connect_button.sensitive = false;
                state.icon_name = "user-away";
                break;
            case Status.DISCONNECTING:
                connect_button.sensitive = false;
                state.icon_name = "user-away";
                break;
            case Status.NOT_CONNECTED:
                connect_button.label = _("Connect");
                connect_button.sensitive = true;
                state.icon_name = "user-offline";
                break;
            case Status.UNABLE_TO_CONNECT:
                connect_button.sensitive = true;
                state.icon_name = "user-busy";
                break;
        }
    }
}
