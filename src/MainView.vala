// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2018 elementary LLC.
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
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Bluetooth.MainView : Granite.SimpleSettingsPage {
    private Gtk.ListBox list_box;
    private Granite.Widgets.OverlayBar overlaybar;

    public Services.ObjectManager manager { get; construct set; }

    public signal void quit_plug ();

    public MainView (Services.ObjectManager manager) {
        Object (
            icon_name: "bluetooth",
            manager: manager,
            title: _("Bluetooth"),
            activatable: true,
            description: ""
        );
    }

    construct {
        var empty_alert = new Granite.Widgets.AlertView (
            _("No Devices Found"),
            _("Please ensure that your devices are visible and ready for pairing."),
            ""
        );
        empty_alert.show_all ();

        list_box = new Gtk.ListBox ();
        list_box.set_sort_func ((Gtk.ListBoxSortFunc) compare_rows);
        list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) title_rows);
        list_box.set_placeholder (empty_alert);
        list_box.selection_mode = Gtk.SelectionMode.BROWSE;
        list_box.activate_on_single_click = true;

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.expand = true;
        scrolled.add (list_box);

        var overlay = new Gtk.Overlay ();
        overlay.add (scrolled);

        overlaybar = new Granite.Widgets.OverlayBar (overlay) {
            label = _("Discovering"),
            active = true
        };

        var frame = new Gtk.Frame (null);
        frame.add (overlay);

        content_area.orientation = Gtk.Orientation.VERTICAL;
        content_area.row_spacing = 0;
        content_area.add (frame);

        margin = 12;
        margin_bottom = 0;

        if (manager.retrieve_finished) {
            complete_setup ();
        } else {
            manager.notify["retrieve-finished"].connect (complete_setup);
        }

        status_switch.notify["active"].connect (() => {
            manager.set_global_state.begin (status_switch.active);
        });

        show_all ();
    }

    private void complete_setup () {
        foreach (var device in manager.get_devices ()) {
            var adapter = manager.get_adapter_from_path (device.adapter);
            var row = new DeviceRow (device, adapter);
            list_box.add (row);
        }

        var first_row = list_box.get_row_at_index (0);
        if (first_row != null) {
            list_box.select_row (first_row);
            list_box.row_activated (first_row);
        }

        update_description ();

        status_switch.active = manager.is_powered;

        /* Now retrieve finished, we can connect manager signals */
       manager.device_added.connect ((device) => {
            var adapter = manager.get_adapter_from_path (device.adapter);
            var row = new DeviceRow (device, adapter);
            list_box.add (row);
            if (list_box.get_selected_row () == null) {
                list_box.select_row (row);
                list_box.row_activated (row);
            }
        });

        manager.device_removed.connect_after ((device) => {
            foreach (var row in list_box.get_children ()) {
                if (((DeviceRow) row).device == device) {
                    list_box.remove (row);
                    break;
                }
            }
        });

        manager.adapter_added.connect ((adapter) => {
            update_description ();
        });

        manager.adapter_removed.connect ((adapter) => {
            if (!manager.has_object) {
                quit_plug ();
            } else {
                update_description ();
            }
        });

        manager.notify["discoverable"].connect (() => {
            update_description ();
        });

        manager.notify["is-powered"].connect (() => {
            update_description ();
        });

        manager.bind_property ("is-discovering", overlaybar, "visible", GLib.BindingFlags.DEFAULT);
        manager.bind_property ("is-powered", status_switch, "active", GLib.BindingFlags.DEFAULT);

        show_all ();
    }

    private void update_description () {
        string? name = manager.get_name ();
        var powered = manager.is_powered;
        if (powered && manager.discoverable) {
            //TRANSLATORS: \"%s\" represents the name of the adapter
            description = _("Now discoverable as \"%s\". Not discoverable when this page is closed").printf (name ?? _("Unknown"));
        } else if (!powered) {
            description = _("Not discoverable while Bluetooth is powered off");
        } else {
            description = _("Not discoverable");
        }

        if (powered) {
            icon_name = "bluetooth";
        } else {
            icon_name = "bluetooth-disabled";
        }
    }

    [CCode (instance_pos = -1)]
    private int compare_rows (DeviceRow row1, DeviceRow row2) {
        unowned Services.Device device1 = row1.device;
        unowned Services.Device device2 = row2.device;
        if (device1.paired && !device2.paired) {
            return -1;
        }

        if (!device1.paired && device2.paired) {
            return 1;
        }

        if (device1.connected && !device2.connected) {
            return -1;
        }

        if (!device1.connected && device2.connected) {
            return 1;
        }

        if (device1.name != null && device2.name == null) {
            return -1;
        }

        if (device1.name == null && device2.name != null) {
            return 1;
        }

        var name1 = device1.name ?? device1.address;
        var name2 = device2.name ?? device2.address;
        return name1.collate (name2);
    }

    [CCode (instance_pos = -1)]
    private void title_rows (DeviceRow row1, DeviceRow? row2) {
        if (row2 == null && row1.device.paired) {
            var label = new Gtk.Label (_("Paired Devices"));
            label.xalign = 0;
            label.margin = 3;
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            row1.set_header (label);
        } else if (row2 == null || row1.device.paired != row2.device.paired) {
            /* This header may not appear, so cannot contain discovery spinner */
            var label = new Gtk.Label (_("Nearby Devices"));
            label.hexpand = true;
            label.xalign = 0;
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            row1.set_header (label);
        } else {
            row1.set_header (null);
        }
    }
}
