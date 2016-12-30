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
 *              Oleksandr Lynok <oleksandr.lynok@gmail.com>
 */

public class Bluetooth.MainView : Gtk.Grid {
    private Gtk.ListBox list_box;
    private unowned Services.ObjectManager manager;

    public MainView (Services.ObjectManager manager) {
        this.manager = manager;

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

        manager.device_removed.connect ((device) => {
            foreach (var row in list_box.get_children ()) {
                if (((DeviceRow) row).device == device) {
                    list_box.remove (row);
                    break;
                }
            }
        });

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
    }

    construct {
        var bluetooth_icon = new Gtk.Image.from_icon_name ("bluetooth", Gtk.IconSize.DIALOG);
        bluetooth_icon.halign = Gtk.Align.START;

        var title = new Gtk.Label (_("Bluetooth"));
        title.get_style_context ().add_class ("h2");
        title.halign = Gtk.Align.START;
        title.hexpand = true;

        list_box = new Gtk.ListBox ();
        list_box.set_sort_func ((Gtk.ListBoxSortFunc) compare_rows);
        list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) title_rows);
        list_box.selection_mode = Gtk.SelectionMode.BROWSE;
        list_box.activate_on_single_click = true;

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.expand = true;
        scrolled.add (list_box);

        var frame = new Gtk.Frame (null);
        frame.margin_top = 24;
        frame.add (scrolled);

        var add_button = new Gtk.ToolButton (null, null);
        add_button.icon_name = "list-add-symbolic";
        add_button.tooltip_text = _("Discover new device");

        var remove_button = new Gtk.ToolButton (null, null);
        remove_button.icon_name = "list-remove-symbolic";
        remove_button.sensitive = false;
        remove_button.tooltip_text = _("Forget selected device");

        var toolbar = new Gtk.Toolbar ();
        toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        toolbar.add (add_button);
        toolbar.add (remove_button);

        column_spacing = 12;
        margin = 24;
        orientation = Gtk.Orientation.VERTICAL;
        attach (bluetooth_icon, 0, 0, 1, 1);
        attach (title, 1, 0, 1, 1);
        attach (frame, 0, 1, 2, 1);
        attach (toolbar, 0, 2, 2, 1);

        add_button.clicked.connect (() => {
            try {
                var appinfo = AppInfo.create_from_commandline ("bluetooth-wizard", null, AppInfoCreateFlags.SUPPORTS_URIS);
                appinfo.launch_uris (null, null);
            } catch (Error e) {
                warning (e.message);
            }
        });

        remove_button.clicked.connect (() => {
            var row = list_box.get_selected_row ();
            if (row != null) {
                unowned Services.Device device = ((DeviceRow) row).device;
                try {
                    Bluetooth.Services.Adapter adapter = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", device.adapter, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                    try {
                        adapter.remove_device (new ObjectPath(((DBusProxy) device).g_object_path));
                    } catch (Error e) {
                        debug ("Removing bluetooth device failed: %s", e.message);
                    }
                } catch (Error e) {
                    debug ("Connecting to bluetooth adapter failed: %s", e.message);
                }
            }
        });

        list_box.row_activated.connect (() => {
            remove_button.sensitive = true;
        });

        list_box.unselect_all.connect (() => {
            remove_button.sensitive = false;
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
}
