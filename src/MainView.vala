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
    private string UNDISCOVERABLE = _("Not discoverable");
    private string POWERED_OFF = _("Not discoverable while Bluetooth is powered off");
    private string DISCOVERABLE = _("Now discoverable as \"%s\". Not discoverable when this page is closed"); //TRANSLATORS: \"%s\" represents the name of the adapter

    private Gtk.ListBox list_box;
    private Gtk.Spinner spinner;
    public Services.ObjectManager manager { get; construct set; }
    private unowned Services.Adapter main_adapter;

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
            "dialog-information"
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

        var frame = new Gtk.Frame (null);
        frame.add (scrolled);

        var remove_button = new Gtk.ToolButton (null, null);
        remove_button.icon_name = "list-remove-symbolic";
        remove_button.sensitive = false;
        remove_button.tooltip_text = _("Forget selected device");

        var toolbar = new Gtk.Toolbar ();
        toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        toolbar.add (remove_button);

        content_area.orientation = Gtk.Orientation.VERTICAL;
        content_area.row_spacing = 0;
        content_area.add (frame);
        content_area.add (toolbar);

        margin = 12;
        margin_bottom = 0;

        remove_button.clicked.connect (() => {
            var row = list_box.get_selected_row ();
            if (row != null) {
                unowned Services.Device device = ((DeviceRow) row).device;
                unowned Services.Adapter adapter = ((DeviceRow) row).adapter;
                try {
                    adapter.remove_device (new ObjectPath(((DBusProxy) device).g_object_path));
                } catch (Error e) {
                    debug ("Removing bluetooth device failed: %s", e.message);
                }
            }
        });

        list_box.row_activated.connect ((row) => {
            remove_button.sensitive = ((DeviceRow) row).device.paired;
        });

        list_box.unselect_all.connect (() => {
            remove_button.sensitive = false;
        });

        foreach (var device in manager.get_devices ()) {
            var adapter = manager.get_adapter_from_path (device.adapter);
            var row = new DeviceRow (device, adapter);
            list_box.add (row);
        }

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
            if (main_adapter == null) {
                set_adapter (adapter);
            }
        });

        manager.adapter_removed.connect ((adapter) => {
            if (main_adapter == adapter) {
                var _adapters = manager.get_adapters ();
                if (!_adapters.is_empty) {
                    set_adapter (_adapters.to_array ()[0]);
                } else {
                    main_adapter = null;
                    quit_plug ();
                }
            }
        });

        if (manager.retrieve_finished) {
            weak Gtk.ListBoxRow? first_row = list_box.get_row_at_index (0);
            if (first_row != null) {
                list_box.select_row (first_row);
                list_box.row_activated (first_row);
            }
        } else {
            manager.notify["retrieve-finished"].connect (() => {
                weak Gtk.ListBoxRow? first_row = list_box.get_row_at_index (0);
                if (first_row != null) {
                    list_box.select_row (first_row);
                    list_box.row_activated (first_row);
                }
            });
        }

        if (manager.has_object) {
            set_adapter (manager.get_adapters ().to_array ()[0]);
            status_switch.active = main_adapter.powered;
        }

        status_switch.notify["active"].connect (() => {
            foreach (var adapter in manager.get_adapters ()) {
                adapter.powered = status_switch.active;
                adapter.discoverable = status_switch.active;
            }

            update_spinner ();
        });

        show_all ();
    }

    private void set_adapter (Services.Adapter adapter) {
        if (main_adapter != null) {
            (main_adapter as DBusProxy).g_properties_changed.disconnect (on_adapter_properties_changed);
        }

        main_adapter = adapter;
        (main_adapter as DBusProxy).g_properties_changed.connect (on_adapter_properties_changed);
        update_description (main_adapter.name, main_adapter.discoverable, main_adapter.powered);
    }

    private void on_adapter_properties_changed (DBusProxy proxy, Variant changed, string[] invalid) {
            var adapter = (Services.Adapter)proxy;
            var powered = changed.lookup_value ("Powered", new VariantType ("b"));
            var name = changed.lookup_value ("Name", new VariantType ("s"));
            var discoverable = changed.lookup_value ("Discoverable", new VariantType ("b"));

            if (powered != null) {
                status_switch.active = adapter.powered;
            }

            if (powered != null || discoverable != null || name != null) {
                update_description (adapter.name, adapter.discoverable, adapter.powered);
            }
    }

    private void update_description (string? name, bool discoverable, bool powered) {
        if (discoverable && powered) {
            description = DISCOVERABLE.printf (name ?? _("Unknown"));
        } else if (!powered) {
            description = POWERED_OFF;
        } else {
            description = UNDISCOVERABLE;
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
            var label = new Gtk.Label (_("Nearby Devices"));
            label.hexpand = true;
            label.xalign = 0;
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

            spinner = new Gtk.Spinner ();
            spinner.halign = Gtk.Align.END;

            update_spinner ();

            var grid = new Gtk.Grid ();
            grid.margin = 3;
            grid.margin_end = 6;
            grid.orientation = Gtk.Orientation.HORIZONTAL;
            grid.add (label);
            grid.add (spinner);
            grid.show_all ();
            row1.set_header (grid);
        } else {
            row1.set_header (null);
        }
    }

    private void update_spinner () {
        if (status_switch.active) {
            spinner.start ();
        } else {
            spinner.stop ();
        }
    }
}
