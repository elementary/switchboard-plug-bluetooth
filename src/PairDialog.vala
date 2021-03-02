/*-
 * Copyright (c) 2018 elementary LLC.
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
 */

public class PairDialog : Granite.MessageDialog {
    public enum AuthType {
        REQUEST_PIN,
        REQUEST_PASSKEY,
        CONFIRMATION,
        NORMAL,
        PASSKEY,
        PIN
    }

    public ObjectPath object_path { get; construct; }
    public AuthType auth_type { get; construct; }
    public string passkey { get; construct; }
    public string pincodes { get; private set; }
    public uint32 passkey_uint32 { get; private set; }

    public PairDialog (ObjectPath object_path, Gtk.Window? main_window) {
        Object (
            auth_type: AuthType.NORMAL,
            buttons: Gtk.ButtonsType.CANCEL,
            object_path: object_path,
            primary_text: _("Confirm Bluetooth Pairing"),
            transient_for: main_window
        );
    }

    public PairDialog.request_pin_code (ObjectPath object_path, Gtk.Window? main_window) {
        Object (
            auth_type: AuthType.REQUEST_PIN,
            buttons: Gtk.ButtonsType.CANCEL,
            object_path: object_path,
            primary_text: _("Enter Bluetooth PIN"),
            transient_for: main_window
        );
    }

    public PairDialog.request_passkey (ObjectPath object_path, Gtk.Window? main_window) {
        Object (
            auth_type: AuthType.REQUEST_PASSKEY,
            buttons: Gtk.ButtonsType.CANCEL,
            object_path: object_path,
            primary_text: _("Enter Bluetooth Passkey"),
            transient_for: main_window
        );
    }

    public PairDialog.display_passkey (ObjectPath object_path, uint32 passkey, uint16 entered, Gtk.Window? main_window) {
        Object (
            auth_type: AuthType.PASSKEY,
            buttons: Gtk.ButtonsType.CANCEL,
            object_path: object_path,
            passkey: "%u".printf (passkey),
            primary_text: _("Confirm Bluetooth Passkey"),
            transient_for: main_window
        );
    }

    public PairDialog.request_confirmation (ObjectPath object_path, uint32 passkey, Gtk.Window? main_window) {
        Object (
            auth_type: AuthType.CONFIRMATION,
            buttons: Gtk.ButtonsType.CANCEL,
            object_path: object_path,
            passkey: "%u".printf (passkey),
            primary_text: _("Confirm Bluetooth Passkey"),
            transient_for: main_window
        );
    }

    public PairDialog.with_pin_code (ObjectPath object_path, string pincode, Gtk.Window? main_window) {
        Object (
            auth_type: AuthType.PIN,
            buttons: Gtk.ButtonsType.CANCEL,
            object_path: object_path,
            passkey: pincode,
            primary_text: _("Enter Bluetooth PIN"),
            transient_for: main_window
        );
    }

    construct {
        Bluetooth.Services.Device device;
        string device_name = _("Unknown Bluetooth Device");
        try {
            device = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", object_path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
            image_icon = new ThemedIcon (device.icon ?? "bluetooth");
            device_name = device.name ?? device.address;
        } catch (IOError e) {
            image_icon = new ThemedIcon ("bluetooth");
            critical (e.message);
        }

        switch (auth_type) {
            case AuthType.REQUESTPIN:
                badge_icon = new ThemedIcon ("dialog-password");
                secondary_text = _("Enter the pin displayed on “%s”").printf (device_name);
                var entry_pin = new Gtk.Entry () {
                    activates_default = true,
                    xalign = 0.5f,
                    input_hints = Gtk.InputHints.NO_SPELLCHECK | Gtk.InputHints.NONE,
                    input_purpose = Gtk.InputPurpose.DIGITS,
                    max_length = 16, // get from doc bluez
                    width_chars = 16
                };
                entry_pin.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
                entry_pin.changed.connect (() => {
                    pincodes = entry_pin.text;
                });
                custom_bin.margin_start = 25;
                custom_bin.margin_end = 25;
                custom_bin.add (entry_pin);
                custom_bin.show_all ();
                var confirm_button = add_button (_("Confirm"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
            case AuthType.REQUEST_PASSKEY:
                badge_icon = new ThemedIcon ("dialog-password");
                secondary_text = _("Enter the passkey displayed on “%s”").printf (device_name);
                var entry_passkey = new Gtk.Entry () {
                    activates_default = true,
                    xalign = 0.5f,
                    input_hints = Gtk.InputHints.NONE,
                    input_purpose = Gtk.InputPurpose.NUMBER,
                    max_length = 6, //get from doc bluez
                    width_chars = 6
                };
                entry_passkey.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
                entry_passkey.changed.connect (() => {
                    passkey_uint32 = (uint32) uint64.parse (entry_passkey.text);
                });
                custom_bin.margin_start = 110;
                custom_bin.margin_end = 110;
                custom_bin.add (entry_passkey);
                custom_bin.show_all ();
                var confirm_button = add_button (_("Confirm"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
            case AuthType.CONFIRMATION:
                badge_icon = new ThemedIcon ("dialog-password");
                secondary_text = _("Make sure the code displayed on “%s” matches the one below.").printf (device_name);
                var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
            case AuthType.PASSKEY:
                badge_icon = new ThemedIcon ("dialog-password");
                secondary_text = _("“%s” would like to pair with this device. Make sure the code displayed on “%s” matches the one below.").printf (device_name, device_name);

                var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
            case AuthType.PIN:
                badge_icon = new ThemedIcon ("dialog-password");
                secondary_text = _("Type the code displayed below on “%s”, followed by Enter.").printf (device_name);
                var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
            case AuthType.NORMAL:
                badge_icon = new ThemedIcon ("dialog-question");
                secondary_text = _("“%s” would like to pair with this device.").printf (device_name);

                var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
        }

        if (passkey != null && passkey != "") {
            var passkey_label = new Gtk.Label (passkey);
            passkey_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

            custom_bin.add (passkey_label);
            custom_bin.show_all ();
        }

        modal = true;
        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.ACCEPT:
                    destroy (); //pass signal method-return
                    break;
                case Gtk.ResponseType.CANCEL:
                    device.blocked = true; // reject with signal block
                    device.disconnect.begin (); // disconnect to close signal
                    destroy ();
                    break;
            }
        });
        destroy.connect (() => {
            device.blocked = false; // remove blocking
        });
    }

    public string get_pincode () {
        return pincodes;
    }
    
    public uint32 get_upasskey () {
        return passkey_uint32;
    }
}
