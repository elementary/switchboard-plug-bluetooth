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

public class Bluetooth.DeviceView : Gtk.Grid {
    unowned Services.Device device;
    Gtk.Image image;
    Gtk.Label label;
    Gtk.Switch enable_switch;
    public DeviceView (Services.Device device) {
        this.device = device;
        label.label = device.name;
        image.icon_name = device.icon;
        enable_switch.active = device.connected;

        (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var connected = changed.lookup_value("Connected", new VariantType("b"));
            if (connected != null) {
                enable_switch.active = device.connected;
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
        margin = 12;
        column_spacing = 12;
        image = new Gtk.Image ();
        image.icon_size = Gtk.IconSize.DIALOG;
        label = new Gtk.Label (null);
        label.valign = Gtk.Align.CENTER;
        label.hexpand = true;
        label.xalign = 0;
        label.get_style_context ().add_class ("h2");
        enable_switch = new Gtk.Switch ();
        enable_switch.valign = Gtk.Align.CENTER;
        attach (image, 0, 0, 1, 1);
        attach (label, 1, 0, 1, 1);
        attach (enable_switch, 2, 0, 1, 1);
        show_all ();
    }
}
