/*
* SPDX-License-Identifier: LGPL-3.0-or-later
* SPDX-FileCopyrightText: 2016-2025 elementary, Inc. (https://elementary.io)
*
* Authored by: Corentin Noël <corentin@elementary.io>
*              Oleksandr Lynok <oleksandr.lynok@gmail.com>
*/

public class Bluetooth.MainView : Switchboard.SettingsPage {
    public signal void quit_plug ();

    private Gtk.SortListModel nearby_model;
    private Gtk.SortListModel paired_model;
    private GLib.ListStore device_model;
    private Gtk.Spinner discovery_spinner;
    private Services.ObjectManager manager;

    public MainView () {
        Object (
            title: _("Bluetooth"),
            activatable: true
        );
    }

    construct {
        device_model = new GLib.ListStore (typeof (Services.Device));

        paired_model = new Gtk.SortListModel (
            new Gtk.FilterListModel (device_model, new Gtk.CustomFilter ((obj) => {
                var device = (Services.Device) obj;
                return device.paired;
            })),
            new Gtk.CustomSorter ((GLib.CompareDataFunc<GLib.Object>) Services.Device.compare)
        );

        nearby_model = new Gtk.SortListModel (
            new Gtk.FilterListModel (device_model, new Gtk.CustomFilter ((obj) => {
                var device = (Services.Device) obj;

                if (device.name == null && device.icon == null) {
                    return false;
                }

                return !device.paired;
            })),
            new Gtk.CustomSorter ((GLib.CompareDataFunc<GLib.Object>) Services.Device.compare)
        );

        var paired_placeholder = new Granite.Placeholder (_("No Paired Devices")) {
            description = _("Bluetooth devices will appear here when paired with this device.")
        };

        var paired_list = new Gtk.ListBox () {
            activate_on_single_click = false,
            overflow = HIDDEN,
            selection_mode = BROWSE
        };
        paired_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);
        paired_list.add_css_class (Granite.STYLE_CLASS_CARD);
        paired_list.add_css_class (Granite.STYLE_CLASS_ROUNDED);
        paired_list.bind_model (paired_model, create_widget_func);
        paired_list.set_placeholder (paired_placeholder);

        var empty_alert = new Granite.Placeholder (_("No Devices Found")) {
            description = _("Please ensure that your devices are visible and ready for pairing.")
        };

        var list_box = new Gtk.ListBox () {
            activate_on_single_click = false,
            overflow = HIDDEN,
            selection_mode = BROWSE
        };
        list_box.add_css_class (Granite.STYLE_CLASS_RICH_LIST);
        list_box.add_css_class (Granite.STYLE_CLASS_CARD);
        list_box.add_css_class (Granite.STYLE_CLASS_ROUNDED);
        list_box.bind_model (nearby_model, create_widget_func);
        list_box.set_placeholder (empty_alert);

        var paired_header = new Granite.HeaderLabel (_("Paired Devices")) {
            margin_bottom = 6,
            mnemonic_widget = paired_list
        };

        var nearby_header = new Granite.HeaderLabel (_("Nearby Devices")) {
            mnemonic_widget = list_box
        };

        discovery_spinner = new Gtk.Spinner ();

        var nearby_box = new Gtk.Box (HORIZONTAL, 6) {
            margin_top = 24,
            margin_bottom = 6,
        };
        nearby_box.append (nearby_header);
        nearby_box.append (discovery_spinner);

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (paired_header);
        box.append (paired_list);
        box.append (nearby_box);
        box.append (list_box);

        child = box;

        manager = Bluetooth.Services.ObjectManager.get_default ();
        if (manager.retrieve_finished) {
            complete_setup ();
        } else {
            manager.notify["retrieve-finished"].connect (complete_setup);
        }

        list_box.row_activated.connect ((row) => {
            ((DeviceRow) row).on_activate.begin ();
        });

        status_switch.notify["active"].connect (() => {
            manager.set_global_state.begin (status_switch.active);
        });
    }

    private void complete_setup () {
        foreach (var device in manager.get_devices ()) {
            on_device_added (device);
        }

        update_description ();

        status_switch.active = manager.is_powered;

        /* Now retrieve finished, we can connect manager signals */
        manager.device_added.connect (on_device_added);

        manager.device_removed.connect_after (on_device_removed);

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

        manager.bind_property ("is-discovering", discovery_spinner, "spinning", DEFAULT);
        manager.bind_property ("is-powered", status_switch, "active", GLib.BindingFlags.DEFAULT);
    }

    private void on_device_added (Services.Device device) {
        uint pos = -1;
        if (device_model.find (device, out pos)) {
            return;
        }

        ((DBusProxy) device).g_properties_changed.connect (on_device_changed);

        device_model.append (device);
    }

    private void on_device_changed (Variant changed, string[] invalidated) {
        var paired = changed.lookup_value ("Paired", new VariantType ("b"));
        if (paired != null) {
            var nearby_filter = ((Gtk.FilterListModel) nearby_model.model).filter;
            var paired_filter = ((Gtk.FilterListModel) paired_model.model).filter;

            if (paired.get_boolean ()) {
                nearby_filter.changed (MORE_STRICT);
                paired_filter.changed (LESS_STRICT);
            } else {
                nearby_filter.changed (LESS_STRICT);
                paired_filter.changed (MORE_STRICT);
            }

            return;
        }

        var connected = changed.lookup_value ("Connected", new VariantType ("b"));
        if (connected != null) {
            paired_model.sorter.changed (DIFFERENT);
            return;
        }

        var name = changed.lookup_value ("Name", new VariantType ("s"));
        if (name != null) {
            paired_model.sorter.changed (DIFFERENT);
        }
    }

    private void on_device_removed (Services.Device device) {
        uint pos = -1;
        if (!device_model.find (device, out pos)) {
            return;
        }

        ((DBusProxy) device).g_properties_changed.disconnect (on_device_changed);

        device_model.remove (pos);
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
            icon = new ThemedIcon ("bluetooth");
        } else {
            icon = new ThemedIcon ("bluetooth-disabled");
        }
    }

    private Gtk.Widget create_widget_func (Object obj) {
        return new DeviceRow ((Services.Device) obj);
    }
}
