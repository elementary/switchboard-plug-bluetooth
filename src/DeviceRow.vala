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

    public signal void status_changed ();

    private enum Status {
        UNPAIRED,
        PAIRING,
        CONNECTED,
        CONNECTING,
        DISCONNECTING,
        NOT_CONNECTED,
        UNABLE_TO_CONNECT,
        UNABLE_TO_CONNECT_PAIRED;

        public string to_string () {
            switch (this) {
                case UNPAIRED:
                    return _("Available");
                case PAIRING:
                    return _("Pairing…");
                case CONNECTED:
                    return _("Connected");
                case CONNECTING:
                    return _("Connecting…");
                case DISCONNECTING:
                    return _("Disconnecting…");
                case UNABLE_TO_CONNECT:
                case UNABLE_TO_CONNECT_PAIRED:
                    return _("Unable to Connect");
                default:
                    return _("Not Connected");
            }
        }
    }

    private Gtk.Button connect_button;
    private Gtk.Button forget_button;
    private Gtk.Image state;
    private Gtk.Label state_label;
    private Gtk.LinkButton settings_button;

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

        string? device_name = device.name;
        if (device_name == null) {
            if (device.icon != null) {
                switch (device.icon) {
                    case "audio-card":
                        device_name = _("Speaker");
                        break;
                    case "input-gaming":
                        device_name = _("Controller");
                        break;
                    case "input-keyboard":
                        device_name = _("Keyboard");
                        break;
                    case "input-mouse":
                        device_name = _("Mouse");
                        break;
                    case "input-tablet":
                        device_name = _("Tablet");
                        break;
                    case "input-touchpad":
                        device_name = _("Touchpad");
                        break;
                    case "phone":
                        device_name = _("Phone");
                        break;
                    default:
                        device_name = device.address;
                }
            } else {
                device_name = device.address;
            }
        }

        var label = new Gtk.Label (device_name);
        label.ellipsize = Pango.EllipsizeMode.END;
        label.hexpand = true;
        label.xalign = 0;

        settings_button = new Gtk.LinkButton ("");
        settings_button.always_show_image = true;
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-horizontal-symbolic", Gtk.IconSize.MENU);
        settings_button.label = null;
        settings_button.margin_end = 3;
        settings_button.show_all ();
        settings_button.no_show_all = true;
        settings_button.visible = false;

        forget_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU) {
            margin_end = 3,
            no_show_all = true,
            tooltip_text = _("Forget this device"),
            visible = false
        };
        forget_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

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
        grid.attach (forget_button, 3, 0, 1, 2);
        grid.attach (connect_button, 4, 0, 1, 2);

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
            case "printer":
                settings_button.uri = "settings://printer";
                settings_button.tooltip_text = _("Printer Settings");
                break;
            default:
                settings_button.uri = null;
                settings_button.tooltip_text = null;
                break;
        }

        compute_status ();
        set_sensitive (adapter.powered);

        (adapter as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var powered = changed.lookup_value ("Powered", new VariantType ("b"));
            if (powered != null) {
                set_sensitive (adapter.powered);
                this.changed ();
            }
        });

        (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var paired = changed.lookup_value ("Paired", new VariantType ("b"));
            if (paired != null) {
                compute_status ();
                device.connect.begin (); // connect after paired
                this.changed ();
            }

            var connected = changed.lookup_value ("Connected", new VariantType ("b"));
            if (connected != null) {
                compute_status ();
                this.changed ();
            }

            var name = changed.lookup_value ("Name", new VariantType ("s"));
            if (name != null) {
                label.label = device.name;
            }

            var icon = changed.lookup_value ("Icon", new VariantType ("s"));
            if (icon != null) {
                image.icon_name = device.icon ?? "bluetooth";
            }
        });

        connect_button.clicked.connect (() => {
            button_clicked.begin ();
            // If pairing is successful, mark devices as trusted so they autoconnect
            device.trusted = device.paired;
        });

        forget_button.button_release_event.connect (() => {
            try {
                adapter.remove_device (new ObjectPath (((DBusProxy) device).g_object_path));
            } catch (Error e) {
                debug ("Forget bluetooth device failed: %s", e.message);
            }
        });

    }

    private async void button_clicked () {
        if (!device.paired) {
            set_status (Status.PAIRING);
            try {
                yield device.pair ();
            } catch (Error e) {
                set_status (Status.UNABLE_TO_CONNECT);
                critical (e.message);
            }
        } else if (!device.connected) {
            set_status (Status.CONNECTING);
            try {
                yield device.connect ();
            } catch (Error e) {
                set_status (Status.UNABLE_TO_CONNECT_PAIRED);
                critical (e.message);
            }
        } else {
            set_status (Status.DISCONNECTING);
            try {
                yield device.disconnect ();
            } catch (Error e) {
                state.icon_name = "user-busy";
                critical (e.message);
            }
        }
    }

    private void compute_status () {
        if (!device.paired) {
            set_status (Status.UNPAIRED);
        } else if (device.connected) {
            set_status (Status.CONNECTED);
        } else {
            set_status (Status.NOT_CONNECTED);
        }
    }

    private void set_status (Status status) {
        state_label.label = GLib.Markup.printf_escaped ("<span font_size='small'>%s</span>", status.to_string ());
        state.no_show_all = false;
        state.visible = true;

        switch (status) {
            case Status.UNPAIRED:
                connect_button.label = _("Pair");
                connect_button.sensitive = true;
                settings_button.visible = false;
                state.no_show_all = true;
                state.visible = false;
                forget_button.visible = false;
                break;
            case Status.PAIRING:
                connect_button.sensitive = false;
                state.icon_name = "user-away";
                settings_button.visible = false;
                forget_button.visible = false;
                break;
            case Status.CONNECTED:
                connect_button.label = _("Disconnect");
                connect_button.sensitive = true;
                state.icon_name = "user-available";
                if (settings_button.uri != "") {
                    settings_button.visible = true;
                }
                forget_button.sensitive = true;
                forget_button.visible = true;
                break;
            case Status.CONNECTING:
                connect_button.sensitive = false;
                state.icon_name = "user-away";
                settings_button.visible = false;
                forget_button.sensitive = false;
                forget_button.visible = true;
                break;
            case Status.DISCONNECTING:
                connect_button.sensitive = false;
                state.icon_name = "user-away";
                settings_button.visible = false;
                forget_button.sensitive = false;
                forget_button.visible = true;
                break;
            case Status.NOT_CONNECTED:
                connect_button.label = _("Connect");
                connect_button.sensitive = true;
                state.icon_name = "user-offline";
                settings_button.visible = false;
                forget_button.sensitive = true;
                forget_button.visible = true;
                break;
            case Status.UNABLE_TO_CONNECT:
                connect_button.sensitive = true;
                state.icon_name = "user-busy";
                settings_button.visible = false;
                forget_button.visible = false;
                break;
            case Status.UNABLE_TO_CONNECT_PAIRED:
                connect_button.sensitive = true;
                state.icon_name = "user-offline";
                settings_button.visible = false;
                forget_button.sensitive = true;
                forget_button.visible = true;
                break;
        }
        status_changed ();
    }
}
