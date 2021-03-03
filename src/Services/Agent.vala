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
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *            : Torikul habib <torik.habib@gmail.com>
 */

[DBus (name = "org.bluez.Error")]
public errordomain BluezError {
    REJECTED,
    CANCELED
}

[DBus (name = "org.bluez.Agent1")]
public class Bluetooth.Services.Agent : Object {
    private const string PATH = "/org/bluez/agent/elementary";
    Gtk.Window? main_window;
    private PairDialog? pair_dialog;
    [DBus (visible=false)]
    public Agent (Gtk.Window? main_window) {
        this.main_window = main_window;
        Bus.own_name (BusType.SYSTEM, "org.bluez.Agent1", GLib.BusNameOwnerFlags.NONE,
            (connection, name) => {
                try {
                    connection.register_object (PATH, this);
                } catch (Error e) {
                    critical (e.message);
                }
            }
        );
    }
    public GLib.ObjectPath get_path () throws Error {
        return new GLib.ObjectPath (PATH);
    }
    public void release () throws Error {
    }

    private bool check_pairing_response (PairDialog dialog) throws BluezError {
        var response = dialog.run ();
        switch (response) {
            case Gtk.ResponseType.ACCEPT:
                dialog.destroy ();
                return true;
            default:
                dialog.destroy ();
                throw new BluezError.CANCELED ("Pairing cancelled");
        }
    }

    public string request_pin_code (ObjectPath device) throws Error, BluezError {
        pair_dialog = new PairDialog.request_pin_code (device, main_window);
        if (check_pairing_response (pair_dialog)) {
            return pair_dialog.entered_pincode;
        }

        // Unreachable as check_pairing response throws errors in false case
        return "";
    }

    public void display_pin_code (ObjectPath device, string pincode) throws Error, BluezError {
        pair_dialog = new PairDialog.display_pin_code (device, pincode, main_window);
        pair_dialog.present ();
    }

    public uint32 request_passkey (ObjectPath device) throws Error, BluezError {
        pair_dialog = new PairDialog.request_passkey (device, main_window);
        if (check_pairing_response (pair_dialog)) {
            return pair_dialog.entered_passkey;
        }

        // Unreachable as check_pairing response throws errors in false case
        return 0;
    }

    public void display_passkey (ObjectPath device, uint32 passkey, uint16 entered) throws Error, BluezError {
        // TODO: display_passkey can be called multiple times during a single pairing process. `entered` is incremented
        // for each digit of the passkey that has been entered. We should update the existing dialog with this information
        // somehow to indicate that the passkey is being accepted
        if (pair_dialog != null && pair_dialog.passkey == "%u".printf (passkey)) {
            return;
        } else {
            pair_dialog.destroy ();
        }

        pair_dialog = new PairDialog.display_passkey (device, passkey, entered, main_window);
        pair_dialog.present ();
    }

    public void request_confirmation (ObjectPath device, uint32 passkey) throws Error, BluezError {
        pair_dialog = new PairDialog.request_confirmation (device, passkey, main_window);
        check_pairing_response (pair_dialog);
    }

    public void request_authorization (ObjectPath device) throws Error, BluezError {
        pair_dialog = new PairDialog.request_authorization (device, main_window);
        check_pairing_response (pair_dialog);
    }

    public void authorize_service (ObjectPath device, string uuid) throws Error, BluezError {
    }

    public void cancel () throws Error {
        if (pair_dialog != null) {
            pair_dialog.destroy (); //Destroy dialog if cancel from device or time out
        }
    }
}
