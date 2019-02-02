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

[DBus (name = "org.freedesktop.DBus.ObjectManager")]
public interface Bluetooth.Services.DBusInterface : Object {
    public signal void interfaces_added (ObjectPath object_path, HashTable<string, HashTable<string, Variant>> param);
    public signal void interfaces_removed (ObjectPath object_path, string[] string_array);

    public abstract HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> get_managed_objects () throws Error;
}

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
    private Bluetooth.Services.DBusInterface object_interface;
    private Bluetooth.Services.AgentManager agent_manager;
    private Bluetooth.Services.Agent agent;
    private Gee.HashMap<string, Bluetooth.Services.Adapter> adapters;
    private Gee.HashMap<string, Bluetooth.Services.Device> devices;

    construct {
        adapters = new Gee.HashMap<string, Bluetooth.Services.Adapter> (null, null);
        devices = new Gee.HashMap<string, Bluetooth.Services.Device> (null, null);

        var settings_schema = SettingsSchemaSource.get_default ().lookup (SCHEMA, true);
        if (settings_schema != null) {
            settings = new Settings (SCHEMA);
        }

        Bus.get_proxy.begin<Bluetooth.Services.DBusInterface> (BusType.SYSTEM, "org.bluez", "/", DBusProxyFlags.NONE, null, (obj, res) => {
            try {
                object_interface = Bus.get_proxy.end (res);
                object_interface.get_managed_objects ().foreach (add_path);
                object_interface.interfaces_added.connect (add_path);
                object_interface.interfaces_removed.connect (remove_path);
            } catch (Error e) {
                critical (e.message);
            }

            retrieve_finished = true;
        });

        notify["discoverable"].connect (() => {
            lock (adapters) {
                foreach (var adapter in adapters.values) {
                    adapter.discoverable = discoverable;
                }
            }
        });
    }

    [CCode (instance_pos = -1)]
    private void add_path (ObjectPath path, HashTable<string, HashTable<string, Variant>> param) {
        if ("org.bluez.Adapter1" in param) {
            try {
                Bluetooth.Services.Adapter adapter = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                lock (adapters) {
                    adapters.set (path, adapter);
                }
                has_object = true;

                adapter_added (adapter);

                (adapter as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
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
            } catch (Error e) {
                debug ("Connecting to bluetooth adapter failed: %s", e.message);
            }
        } else if ("org.bluez.Device1" in param) {
            try {
                Bluetooth.Services.Device device = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                lock (devices) {
                    devices.set (path, device);
                }

                device_added (device);

                (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
                    var connected = changed.lookup_value ("Connected", GLib.VariantType.BOOLEAN);
                    if (connected != null) {
                        check_global_state ();
                    }
                });

                check_global_state ();
            } catch (Error e) {
                debug ("Connecting to bluetooth device failed: %s", e.message);
            }
        }
    }

    public void check_discovering () {
        foreach (var adapter in adapters.values) {
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
        foreach (var adapter in adapters.values) {
            if (adapter.discoverable != discoverable) {
                adapter.discoverable = discoverable;
            }
        }
    }

    [CCode (instance_pos = -1)]
    public void remove_path (ObjectPath path) {
        lock (adapters) {
            var adapter = adapters.get (path);
            if (adapter != null) {
                adapters.unset (path);
                has_object = !adapters.is_empty;

                adapter_removed (adapter);
                return;
            }
        }

        lock (devices) {
            var device = devices.get (path);
            if (device != null) {
                devices.unset (path);
                device_removed (device);
            }
        }
    }

    public string? get_name () {
        lock (adapters) {
            if (adapters.is_empty) {
                return null;
            } else {
                return adapters.values.to_array ()[0].name;
            }
        }
    }

    public Gee.Collection<Bluetooth.Services.Adapter> get_adapters () {
        lock (adapters) {
            return adapters.values;
        }
    }

    public Gee.Collection<Bluetooth.Services.Device> get_devices () {
        lock (devices) {
            return devices.values;
        }
    }

    public Bluetooth.Services.Adapter? get_adapter_from_path (string path) {
        lock (adapters) {
            return adapters.get (path);
        }
    }

    private async void create_agent () {
        try {
            agent_manager = yield Bus.get_proxy<Bluetooth.Services.AgentManager> (BusType.SYSTEM, "org.bluez", "/org/bluez", DBusProxyFlags.NONE);
        } catch (Error e) {
            critical (e.message);
        }

        agent = new Bluetooth.Services.Agent ();
        agent.notify["ready"].connect (() => {
            if (is_registered) {
                register_agent ();
            }
        });

        agent.unregistered.connect (() => {
            is_registered = false;
        });
    }

    public async void register_agent () {
        is_registered = true;
        if (agent_manager == null) {
            yield create_agent ();
        }

        if (agent.ready) {
            try {
                agent_manager.register_agent (agent.get_path (), "DisplayYesNo");
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    public async void unregister_agent () {
        is_registered = false;
        if (agent.ready) {
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
        lock (adapters) {
            is_discovering = true;
            foreach (var adapter in adapters.values) {
                try {
                    yield adapter.start_discovery ();
                } catch (Error e) {
                    critical (e.message);
                }
            }
        }
    }

    public async void stop_discovery () {
        lock (adapters) {
            is_discovering = false;
            foreach (var adapter in adapters.values) {
                try {
                    if (adapter.powered && adapter.discovering) {
                        yield adapter.stop_discovery ();
                    }
                } catch (Error e) {
                    critical (e.message);
                }
            }
        }
    }

    public bool get_connected () {
        lock (devices) {
            foreach (var device in devices.values) {
                if (device.connected) {
                    return true;
                }
            }
        }

        return false;
    }

    public bool get_global_state () {
        lock (adapters) {
            foreach (var adapter in adapters.values) {
                if (adapter.powered) {
                    return true;
                }
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

        lock (adapters) {
            foreach (var adapter in adapters.values) {
                adapter.powered = state;
                adapter.discoverable = state;
            }
        }

        if (settings != null) {
            settings.set_boolean ("bluetooth-enabled", state);
        }

        if (!state) {
            lock (devices) {
                foreach (var device in devices.values) {
                    if (device.connected) {
                        try {
                            yield device.disconnect ();
                        } catch (Error e) {
                            critical (e.message);
                        }
                    }
                }
            }
        } else {
            start_discovery.begin ();
        }
    }
}
