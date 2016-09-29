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
    public Services.Device device;
    private Gtk.Label label;
    private Gtk.Image image;
    private Gtk.Image state;

    public DeviceRow (Services.Device device) {
        this.device = device;
        label.label = device.name;
        image.icon_name = device.icon;
        if (device.connected) {
            state.icon_name = "user-available";
        }

        (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var connected = changed.lookup_value("Connected", new VariantType("b"));
            if (connected != null) {
                if (device.connected) {
                    state.icon_name = "user-available";
                } else {
                    state.icon_name = "user-offline";
                }
            }

            var name = changed.lookup_value("Name", new VariantType("s"));
            if (name != null) {
                label.label = device.name;
            }

            var icon = changed.lookup_value("Icon", new VariantType("s"));
            if (icon != null) {
                image.icon_name = device.icon;
            }
        });
    }

    construct {
        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.column_spacing = 6;
        grid.orientation = Gtk.Orientation.HORIZONTAL;

        image = new Gtk.Image ();
        image.icon_size = Gtk.IconSize.DND;

        state = new Gtk.Image.from_icon_name ("user-offline", Gtk.IconSize.MENU);
        state.halign = Gtk.Align.END;
        state.valign = Gtk.Align.END;

        var overay = new Gtk.Overlay ();
        overay.add (image);
        overay.add_overlay (state);

        label = new Gtk.Label (null);
        label.ellipsize = Pango.EllipsizeMode.END;
        grid.add (overay);
        grid.add (label);
        add (grid);
        show_all ();
    }
}
