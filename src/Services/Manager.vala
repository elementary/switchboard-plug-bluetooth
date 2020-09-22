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

[DBus (name = "org.bluez.AgentManager1")]
public interface Bluetooth.Services.AgentManager : Object {
    public abstract void register_agent (ObjectPath agent, string capability) throws Error;
    public abstract void request_default_agent (ObjectPath agent) throws Error;
    public abstract void unregister_agent (ObjectPath agent) throws Error;
}

public class Bluetooth.Services.ObjectManager : Object {
    private const string SCHEMA = "io.elementary.desktop.wingpanel.bluetooth";
    public signal void adapter_added (Bluetooth.Services.Adapter adapter);
    public signal void adapter_removed (Bluetooth.Services.Adapter adapter);
    public signal void device_added (Bluetooth.Services.Device device);
    public signal void device_removed (Bluetooth.Services.Device device);

    public bool discoverable { get; set; default = false; }
    public bool has_object { get; private set; default = false; }
    public bool retrieve_finished { get; private set; default = false; }

    public bool is_discovering {get; private set; default = false; }
    public bool is_powered {get; private set; default = false; }
    public bool is_connected {get; private set; default = false; }

    private bool is_registered = false;

    private Settings? settings = null;
    private GLib.DBusObjectManagerClient object_manager;
    private Bluetooth.Services.AgentManager agent_manager;
    private Bluetooth.Services.Agent agent;

    construct {
        var settings_schema = SettingsSchemaSource.get_default ().lookup (SCHEMA, true);
        if (settings_schema != null) {
            settings = new Settings (SCHEMA);
        }
        create_manager.begin ();

        notify["discoverable"].connect (() => {
            get_adapters ().foreach ((adapter) => adapter.discoverable = discoverable);
        });
    }

    private async void create_manager () {
        try {
            object_manager = yield new GLib.DBusObjectManagerClient.for_bus.begin (
                BusType.SYSTEM,
                GLib.DBusObjectManagerClientFlags.NONE,
                "org.bluez",
                "/",
                object_manager_proxy_get_type,
                null
            );
            if (object_manager == null) {
                return;
            }
            object_manager.get_objects ().foreach ((object) => {
                object.get_interfaces ().foreach ((iface) => on_interface_added (object, iface));
            });
            object_manager.interface_added.connect (on_interface_added);
            object_manager.interface_removed.connect (on_interface_removed);
            object_manager.object_added.connect ((object) => {
                object.get_interfaces ().foreach ((iface) => on_interface_added (object, iface));
            });
            object_manager.object_removed.connect ((object) => {
                object.get_interfaces ().foreach ((iface) => on_interface_removed (object, iface));
            });
        } catch (Error e) {
            critical (e.message);
        }

        retrieve_finished = true;
    }

    //TODO: Do not rely on this when it is possible to do it natively in Vala
    [CCode (cname="bluetooth_services_device_proxy_get_type")]
    extern static GLib.Type get_device_proxy_type ();

    [CCode (cname="bluetooth_services_adapter_proxy_get_type")]
    extern static GLib.Type get_adapter_proxy_type ();

    [CCode (cname="bluetooth_services_agent_manager_proxy_get_type")]
    extern static GLib.Type get_agent_manager_proxy_type ();

    private GLib.Type object_manager_proxy_get_type (DBusObjectManagerClient manager, string object_path, string? interface_name) {
        if (interface_name == null)
            return typeof (GLib.DBusObjectProxy);

        switch (interface_name) {
            case "org.bluez.Device1":
                return get_device_proxy_type ();
            case "org.bluez.Adapter1":
                return get_adapter_proxy_type ();
            case "org.bluez.AgentManager1":
                return get_agent_manager_proxy_type ();
            default:
                return typeof (GLib.DBusProxy);
        }
    }

    private void on_interface_added (GLib.DBusObject object, GLib.DBusInterface iface) {
        if (iface is Bluetooth.Services.Device) {
            unowned Bluetooth.Services.Device device = (Bluetooth.Services.Device) iface;

            device_added (device);
            ((DBusProxy) device).g_properties_changed.connect ((changed, invalid) => {
                var connected = changed.lookup_value ("Connected", GLib.VariantType.BOOLEAN);
                if (connected != null) {
                    check_global_state ();
                }

                var paired = changed.lookup_value ("Paired", GLib.VariantType.BOOLEAN);
                if (paired != null) {
                    check_global_state ();
                }
            });

            check_global_state ();
        } else if (iface is Bluetooth.Services.Adapter) {
            unowned Bluetooth.Services.Adapter adapter = (Bluetooth.Services.Adapter) iface;
            has_object = true;

            adapter_added (adapter);
            ((DBusProxy) adapter).g_properties_changed.connect ((changed, invalid) => {
                var powered = changed.lookup_value ("Powered", GLib.VariantType.BOOLEAN);
                if (powered != null) {
                    check_global_state ();
                }

                var discovering = changed.lookup_value ("Discovering", GLib.VariantType.BOOLEAN);
                if (discovering != null) {
                    check_discovering ();
                }

                var adapter_discoverable = changed.lookup_value ("Discoverable", GLib.VariantType.BOOLEAN);
                if (adapter_discoverable != null) {
                    check_discoverable ();
                }
            });

            check_global_state ();
        }
    }

    private void on_interface_removed (GLib.DBusObject object, GLib.DBusInterface iface) {
        if (iface is Bluetooth.Services.Device) {
            device_removed ((Bluetooth.Services.Device) iface);
        } else if (iface is Bluetooth.Services.Adapter) {
            adapter_removed ((Bluetooth.Services.Adapter) iface);
            has_object = !get_adapters ().is_empty;
        }
    }

    public void check_discovering () {
        var adapters = get_adapters ();
        foreach (var adapter in adapters) {
            if (adapter.discovering != is_discovering) {
                if (is_discovering) {
                    adapter.start_discovery.begin ();
                } else {
                    adapter.stop_discovery.begin ();
                }
            }
        }
    }

    public void check_discoverable () {
        var adapters = get_adapters ();
        foreach (var adapter in adapters) {
            if (adapter.discoverable != discoverable) {
                adapter.discoverable = discoverable;
            }
        }
    }

    public string? get_name () {
        var adapters = get_adapters ();
        if (adapters.is_empty) {
            return null;
        } else {
            return adapters.first ().name;
        }
    }

    public Gee.LinkedList<Bluetooth.Services.Adapter> get_adapters () {
        var adapters = new Gee.LinkedList<Bluetooth.Services.Adapter> ();
        if (object_manager != null) {
            object_manager.get_objects ().foreach ((object) => {
                GLib.DBusInterface? iface = object.get_interface ("org.bluez.Adapter1");
                if (iface == null)
                    return;

                adapters.add (((Bluetooth.Services.Adapter) iface));
            });
        }

        return (owned) adapters;
    }

    public Gee.Collection<Bluetooth.Services.Device> get_devices () {
        var devices = new Gee.LinkedList<Bluetooth.Services.Device> ();
        if (object_manager != null) {
            object_manager.get_objects ().foreach ((object) => {
                GLib.DBusInterface? iface = object.get_interface ("org.bluez.Device1");
                if (iface == null)
                    return;

                devices.add (((Bluetooth.Services.Device) iface));
            });
        }

        return (owned) devices;
    }

    public Bluetooth.Services.Adapter? get_adapter_from_path (string path) {
        GLib.DBusObject? object = object_manager.get_object (path);
        if (object != null) {
            return (Bluetooth.Services.Adapter?) object.get_interface ("org.bluez.Adapter1");
        }

        return null;
    }

    private async void create_agent (Gtk.Window? window) {
        if (object_manager == null) {
            return;
        }
        GLib.DBusObject? bluez_object = object_manager.get_object ("/org/bluez");
        if (bluez_object != null) {
            agent_manager = (Bluetooth.Services.AgentManager) bluez_object.get_interface ("org.bluez.AgentManager1");
        }

        agent = new Bluetooth.Services.Agent (window);
        agent.notify["ready"].connect (() => {
            if (is_registered) {
                register_agent.begin (window);
            }
        });

        agent.unregistered.connect (() => {
            is_registered = false;
        });
    }

    public async void register_agent (Gtk.Window? window) {
        is_registered = true;
        if (agent_manager == null) {
            yield create_agent (window);
        }

        if (agent_manager != null && agent.ready) {
            try {
                agent_manager.register_agent (agent.get_path (), "DisplayYesNo");
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    public async void unregister_agent () {
        is_registered = false;
        if (agent_manager != null && agent.ready) {
            try {
                agent_manager.unregister_agent (agent.get_path ());
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    public void check_global_state () {
        /* As this is called within a signal handler and emits a signal
         * it should be in a Idle loop  else races occur */
        Idle.add (() => {
            var powered = get_global_state ();
            var connected = get_connected ();

            /* Only signal if actually changed */
            if (powered != is_powered || connected != is_connected) {
                if (!powered) {
                    discoverable = false;
                }

                is_connected = connected;
                is_powered = powered;
            }

            return false;
        });
    }

    public async void start_discovery () {
        var adapters = get_adapters ();
        is_discovering = true;
        foreach (var adapter in adapters) {
            try {
                yield adapter.start_discovery ();
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    public async void stop_discovery () {
        var adapters = get_adapters ();
        is_discovering = false;
        foreach (var adapter in adapters) {
            try {
                if (adapter.powered && adapter.discovering) {
                    yield adapter.stop_discovery ();
                }
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    public bool get_connected () {
        var devices = get_devices ();
        foreach (var device in devices) {
            if (device.connected) {
                return true;
            }
        }

        return false;
    }

    public bool get_global_state () {
        var adapters = get_adapters ();
        foreach (var adapter in adapters) {
            if (adapter.powered) {
                return true;
            }
        }

        return false;
    }

    public async void set_global_state (bool state) {
        if (state == is_powered && discoverable == state && is_discovering == state) {
            return;
        }

        /* Set discoverable first so description is correct */
        discoverable = state;
        is_powered = state;

        if (!state) {
            yield stop_discovery ();
        }

        var adapters = get_adapters ();
        foreach (var adapter in adapters) {
            adapter.powered = state;
            adapter.discoverable = state;
        }

        if (settings != null) {
            settings.set_boolean ("bluetooth-enabled", state);
        }

        if (!state) {
            var devices = get_devices ();
            foreach (var device in devices) {
                if (device.connected) {
                    try {
                        yield device.disconnect ();
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            }
        } else {
            start_discovery.begin ();
        }
    }
}
