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

public class Bluetooth.HeaderAdapter : Gtk.Grid {
    public unowned Services.Adapter adapter { get; construct; }
    Gtk.Label label;
    Gtk.Switch adapter_switch;

    public HeaderAdapter (Services.Adapter adapter) {
        Object (adapter: adapter);
    }

    construct {
        margin = 3;

        label = new Gtk.Label (_("Now Discoverable as \"%s\"").printf (adapter.name));
        label.get_style_context ().add_class ("h4");
        label.hexpand = true;
        label.xalign = 0;
        label.valign = Gtk.Align.CENTER;
        label.ellipsize = Pango.EllipsizeMode.END;

        adapter_switch = new Gtk.Switch ();
        adapter_switch.active = adapter.powered;
        adapter_switch.margin_end = 3;
        adapter_switch.valign = Gtk.Align.CENTER;

        add (label);
        add (adapter_switch);
        show_all ();

        (adapter as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
            var powered = changed.lookup_value ("Powered", new VariantType ("b"));
            if (powered != null) {
                adapter_switch.active = adapter.powered;
            }

            var name = changed.lookup_value ("Name", new VariantType ("s"));
            if (name != null) {
                label.label = _("Now Discoverable as \"%s\"").printf (adapter.name);
            }
        });

        adapter_switch.notify["active"].connect (() => {
            if (adapter_switch.active & !adapter.powered) {
                adapter.powered = true;
            } else if (!adapter_switch.active & adapter.powered) {
                adapter.powered = false;
            }
        });
    }
}
