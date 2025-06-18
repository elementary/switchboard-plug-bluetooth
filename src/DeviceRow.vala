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
        var image = new Gtk.Image.from_icon_name (device.icon ?? "bluetooth") {
            pixel_size = 32
        };

        state = new Gtk.Image.from_icon_name ("emblem-disabled");
        state.halign = Gtk.Align.END;
        state.valign = Gtk.Align.END;

        state_label = new Gtk.Label (null) {
            xalign = 0
        };
        state_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var overlay = new Gtk.Overlay () {
            child = image,
            tooltip_text = device.address
        };
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

        settings_button = new Gtk.LinkButton ("") {
            child = new Gtk.Image.from_icon_name ("view-more-horizontal-symbolic"),
            margin_end = 3,
            valign = CENTER,
            visible = false
        };

        forget_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
            has_frame = false,
            margin_end = 3,
            tooltip_text = _("Forget this device"),
            valign = CENTER,
            visible = false
        };

        connect_button = new Gtk.Button () {
            valign = CENTER
        };

        size_group.add_widget (connect_button);

        var grid = new Gtk.Grid () {
            column_spacing = 6
        };
        grid.attach (overlay, 0, 0, 1, 2);
        grid.attach (label, 1, 0);
        grid.attach (state_label, 1, 1);
        grid.attach (settings_button, 2, 0, 1, 2);
        grid.attach (forget_button, 3, 0, 1, 2);
        grid.attach (connect_button, 4, 0, 1, 2);

        child = grid;

        switch (device.icon) {
            case "audio-card":
            case "audio-headphones":
            case "audio-headset":
                settings_button.uri = "settings://sound";
                settings_button.tooltip_text = _("Sound Settings");
                break;
            case "input-gaming":
            case "input-keyboard":
                settings_button.uri = "settings://input/keyboard";
                settings_button.tooltip_text = _("Keyboard Settings");
                break;
            case "input-mouse":
                settings_button.uri = "settings://input/pointer/mouse";
                settings_button.tooltip_text = _("Mouse & Touchpad Settings");
                break;
            case "printer":
                settings_button.uri = "settings://printer";
                settings_button.tooltip_text = _("Printer Settings");
                break;
            default:
                settings_button.uri = "";
                settings_button.tooltip_text = null;
                break;
        }

        compute_status ();
        set_sensitive (adapter.powered);

        ((DBusProxy)adapter).g_properties_changed.connect ((changed, invalid) => {
            var powered = changed.lookup_value ("Powered", new VariantType ("b"));
            if (powered != null) {
                set_sensitive (adapter.powered);
                this.changed ();
            }
        });

        ((DBusProxy)device).g_properties_changed.connect ((changed, invalid) => {
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

        forget_button.clicked.connect (() => {
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
        state_label.label = status.to_string ();
        state.visible = true;

        switch (status) {
            case Status.UNPAIRED:
                connect_button.label = _("Pair");
                connect_button.sensitive = true;
                settings_button.visible = false;
                state.visible = false;
                forget_button.visible = false;
                break;
            case Status.PAIRING:
                connect_button.sensitive = false;
                state.icon_name = "emblem-mixed";
                settings_button.visible = false;
                forget_button.visible = false;
                break;
            case Status.CONNECTED:
                connect_button.label = _("Disconnect");
                connect_button.sensitive = true;
                state.icon_name = "emblem-enabled";
                if (settings_button.uri != "") {
                    settings_button.visible = true;
                }
                forget_button.sensitive = true;
                forget_button.visible = true;
                break;
            case Status.CONNECTING:
                connect_button.sensitive = false;
                state.icon_name = "emblem-mixed";
                settings_button.visible = false;
                forget_button.sensitive = false;
                forget_button.visible = true;
                break;
            case Status.DISCONNECTING:
                connect_button.sensitive = false;
                state.icon_name = "emblem-mixed";
                settings_button.visible = false;
                forget_button.sensitive = false;
                forget_button.visible = true;
                break;
            case Status.NOT_CONNECTED:
                connect_button.label = _("Connect");
                connect_button.sensitive = true;
                state.icon_name = "emblem-disabled";
                settings_button.visible = false;
                forget_button.sensitive = true;
                forget_button.visible = true;
                break;
            case Status.UNABLE_TO_CONNECT:
                connect_button.sensitive = true;
                state.icon_name = "emblem-error";
                settings_button.visible = false;
                forget_button.visible = false;
                break;
            case Status.UNABLE_TO_CONNECT_PAIRED:
                connect_button.sensitive = true;
                state.icon_name = "emblem-error";
                settings_button.visible = false;
                forget_button.sensitive = true;
                forget_button.visible = true;
                break;
        }
        status_changed ();
    }
}
