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
    public PairDialog (ObjectPath device) {
        Object (
            image_icon: new ThemedIcon ("dialog-question"),
            primary_text: _("Confirm Bluetooth Pairing"),
            secondary_text: _("\"%s\" would like to pair with this device.").printf ("Helix-Sama")
        );

        var confirm_button = add_button (_("Pair"), Gtk.ResponseType.ACCEPT);
        confirm_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
    }

    public PairDialog.with_passkey (ObjectPath device, uint32 passkey) {
        Object (
            image_icon: new ThemedIcon ("dialog-information"),
            primary_text: _("Confirm Bluetooth Passkey"),
            secondary_text: _("Make sure the code displayed on \"%s\" matches the one below.").printf ("Helix-Sama")
        );

        var passkey_label = new Gtk.Label ((passkey).to_string ());
        passkey_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        custom_bin.add (passkey_label);
        custom_bin.show_all ();
    }

    public PairDialog.with_pin_code (ObjectPath device, string pincode) {
        Object (
            image_icon: new ThemedIcon ("dialog-information"),
            primary_text: _("Confirm Bluetooth PIN"),
            secondary_text: _("Make sure the code displayed on \"%s\" matches the one below.").printf ("Helix-Sama")
        );

        var pin_label = new Gtk.Label (pincode);
        pin_label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        custom_bin.add (pin_label);
        custom_bin.show_all ();
    }

    construct {
        buttons = Gtk.ButtonsType.CANCEL;
        deletable = false;
        modal = true;
        resizable = false;

        response.connect (on_response);
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.CANCEL:
                destroy ();
                break;
        }
    }
}
