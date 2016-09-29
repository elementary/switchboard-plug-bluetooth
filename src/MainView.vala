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

public class Bluetooth.MainView : Gtk.Paned {
    private Gtk.ListBox list_box;
    private Gtk.Stack stack;
    private Bluetooth.Services.ObjectManager manager;

    public MainView () {
        
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        list_box = new Gtk.ListBox ();
        list_box.set_sort_func ((Gtk.ListBoxSortFunc) compare_rows);
        list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) title_rows);
        list_box.selection_mode = Gtk.SelectionMode.BROWSE;
        list_box.activate_on_single_click = true;

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.width_request = 200;
        scrolled.expand = true;
        scrolled.add (list_box);

        var add_button = new Gtk.ToolButton (null, null);
        add_button.icon_name = "list-add-symbolic";

        var toolbar = new Gtk.Toolbar ();
        toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        toolbar.add (add_button);

        var left_grid = new Gtk.Grid ();
        left_grid.orientation = Gtk.Orientation.VERTICAL;
        left_grid.add (scrolled);
        left_grid.add (toolbar);

        stack = new Gtk.Stack ();

        pack1 (left_grid, false, false);
        pack2 (stack, true, false);

        manager = new Bluetooth.Services.ObjectManager ();
        foreach (var device in manager.get_devices ()) {
            var row = new DeviceRow (device);
            list_box.add (row);
        }

        if (manager.retreive_finished) {
            weak Gtk.ListBoxRow? first_row = list_box.get_row_at_index (0);
            if (first_row != null) {
                list_box.select_row (first_row);
                list_box.row_activated (first_row);
            }
        } else {
            manager.notify["retreive-finished"].connect (() => {
                weak Gtk.ListBoxRow? first_row = list_box.get_row_at_index (0);
                if (first_row != null) {
                    list_box.select_row (first_row);
                    list_box.row_activated (first_row);
                }
            });
        }

        manager.device_added.connect ((device) => {
            var row = new DeviceRow (device);
            list_box.add (row);
            if (list_box.get_selected_row () == null) {
                list_box.select_row (row);
                list_box.row_activated (row);
            }
        });

        add_button.clicked.connect (() => {
            try {
                var appinfo = AppInfo.create_from_commandline ("bluetooth-wizard", null, AppInfoCreateFlags.SUPPORTS_URIS);
                appinfo.launch_uris (null, null);
            } catch (Error e) {
                warning (e.message);
            }
        });

        list_box.row_activated.connect ((row) => {
            unowned Services.Device device = ((DeviceRow) row).device;
            weak Gtk.Widget? widget = stack.get_child_by_name (device.address);
            if (widget == null) {
                var device_view = new DeviceView (device);
                stack.add_named (device_view, device.address);
                stack.set_visible_child (device_view);
            } else {
                stack.set_visible_child (widget);
            }
        });

        show_all ();
    }

    public void discoverable (bool is_discoverable) {
        foreach (var adapter in manager.get_adapters ()) {
            if (adapter.powered) {
                adapter.discoverable = is_discoverable;
            }
        }
    }

    [CCode (instance_pos = -1)]
    private int compare_rows (DeviceRow row1, DeviceRow row2) {
        unowned Services.Device device1 = row1.device;
        unowned Services.Device device2 = row2.device;
        if (device1.adapter == device2.adapter) {
            return device1.name.collate (device2.name);
        }

        return device1.adapter.collate (device2.adapter);
    }

    [CCode (instance_pos = -1)]
    private void title_rows (DeviceRow row1, DeviceRow? row2) {
        if (row2 == null || strcmp (row1.device.adapter.dup (), row2.device.adapter.dup ()) != 0) {
            var adapter1 = manager.get_adapter_from_path (row1.device.adapter);
            if (adapter1 != null) {
                row1.set_header (new HeaderAdapter (adapter1));
            } else {
                row1.set_header (null);
            }
        } else {
            row1.set_header (null);
        }
    }

    public class HeaderAdapter : Gtk.Grid {
        unowned Services.Adapter adapter;
        Gtk.Label label;
        Gtk.Switch adapter_switch;

        public HeaderAdapter (Services.Adapter adapter) {
            this.adapter = adapter;
            label.label = adapter.name;
            adapter_switch.active = adapter.powered;
            (adapter as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
                var powered = changed.lookup_value("Powered", new VariantType("b"));
                if (powered != null) {
                    adapter_switch.active = adapter.powered;
                }

                var name = changed.lookup_value("Name", new VariantType("s"));
                if (name != null) {
                    label.label = adapter.name;
                }
            });
        }

        construct {
            margin = 3;
            label = new Gtk.Label (null);
            label.get_style_context ().add_class ("h4");
            label.hexpand = true;
            label.xalign = 0;
            label.valign = Gtk.Align.CENTER;
            label.ellipsize = Pango.EllipsizeMode.END;
            adapter_switch = new Gtk.Switch ();
            adapter_switch.valign = Gtk.Align.CENTER;
            add (label);
            add (adapter_switch);
            show_all ();
        }
    }
}
