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
        CONFIRMATION,
        NORMAL,
        PASSKEY,
        PIN
    }

    public ObjectPath object_path { get; construct; }
    public AuthType auth_type { get; construct; }

    public PairDialog (ObjectPath object_path) {
        Object (
            auth_type: AuthType.NORMAL,
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-question"),
            object_path: object_path,
            primary_text: _("Confirm Bluetooth Pairing")
        );
    }

    public PairDialog.display_passkey (ObjectPath object_path, uint32 passkey, uint16 entered) {
        Object (
            auth_type: AuthType.PASSKEY,
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-information"),
            object_path: object_path,
            primary_text: _("Confirm Bluetooth Passkey")
        );

        var passkey_label = new Gtk.Label ("%u".printf (passkey));
        passkey_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        custom_bin.add (passkey_label);
        custom_bin.show_all ();
    }

    public PairDialog.request_confirmation (ObjectPath object_path, uint32 passkey) {
        Object (
            auth_type: AuthType.CONFIRMATION,
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-information"),
            object_path: object_path,
            primary_text: _("Confirm Bluetooth Passkey")
        );

        var passkey_label = new Gtk.Label ("%u".printf (passkey));
        passkey_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        custom_bin.add (passkey_label);
        custom_bin.show_all ();
    }

    public PairDialog.with_pin_code (ObjectPath object_path, string pincode) {
        Object (
            auth_type: AuthType.PIN,
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-information"),
            object_path: object_path,
            primary_text: _("Confirm Bluetooth PIN")
        );

        var pin_label = new Gtk.Label (pincode);
        pin_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        custom_bin.add (pin_label);
        custom_bin.show_all ();
    }

    construct {
        Bluetooth.Services.Device device = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", object_path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);

        var device_name = device.name ?? device.address;

        switch (auth_type) {
            case AuthType.CONFIRMATION:
                secondary_text = _("Make sure the code displayed on “%s” matches the one below.").printf (device_name);
                break;
            case AuthType.PASSKEY:
                secondary_text = _("“%s” would like to pair with this device. Make sure the code displayed on “%s” matches the one below.").printf (device_name, device_name);

                var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            case AuthType.PIN:
                secondary_text = _("Type the code displayed below on “%s” and press Enter.").printf (device_name);
                break;
            case AuthType.NORMAL:
                secondary_text = _("“%s” would like to pair with this device.").printf (device_name);

                var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
                confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                break;
        }

        modal = true;

        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.ACCEPT:
                    device.pair ();
                    break;
                case Gtk.ResponseType.CANCEL:
                    destroy ();
                    break;
            }
        });

        (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var paired = changed.lookup_value ("Paired", new VariantType ("b"));
            if (paired != null && device.paired) {
                destroy ();
            }
        });
    }
}
