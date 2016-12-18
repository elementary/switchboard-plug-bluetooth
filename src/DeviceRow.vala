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

    public DeviceRow (Services.Device device) {
        Object (device: device);
    }

    construct {
        var image = new Gtk.Image.from_icon_name (device.icon, Gtk.IconSize.DND);

        var state = new Gtk.Image.from_icon_name ("user-offline", Gtk.IconSize.MENU);
        state.halign = Gtk.Align.END;
        state.valign = Gtk.Align.END;

        var overay = new Gtk.Overlay ();
        overay.add (image);
        overay.add_overlay (state);

        var label = new Gtk.Label (device.name);
        label.ellipsize = Pango.EllipsizeMode.END;

        var enable_switch = new Gtk.Switch ();
        enable_switch.active = device.connected;
        enable_switch.halign = Gtk.Align.END;
        enable_switch.hexpand = true;
        enable_switch.valign = Gtk.Align.CENTER;

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.column_spacing = 6;
        grid.orientation = Gtk.Orientation.HORIZONTAL;
        grid.add (overay);
        grid.add (label);
        grid.add (enable_switch);
        add (grid);
        show_all ();

        if (device.connected) {
            state.icon_name = "user-available";
        }

        (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var connected = changed.lookup_value ("Connected", new VariantType ("b"));
            if (connected != null) {
                if (device.connected) {
                    state.icon_name = "user-available";
                } else {
                    state.icon_name = "user-offline";
                }
                enable_switch.active = device.connected;
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
    }
}
