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

    public abstract HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> get_managed_objects () throws IOError;
}

public class Bluetooth.Services.ObjectManager : Object {
    private const string SCHEMA = "org.pantheon.desktop.wingpanel.indicators.bluetooth";
    public signal void global_state_changed (bool enabled, bool connected);
    public signal void adapter_added (Bluetooth.Services.Adapter adapter);
    public signal void adapter_removed (Bluetooth.Services.Adapter adapter);
    public signal void device_added (Bluetooth.Services.Device device);
    public signal void device_removed (Bluetooth.Services.Device device);

    public bool has_object { get; private set; default = false; }
    public bool retrieve_finished { get; private set; default = false; }

    private Settings? settings = null;
    private Bluetooth.Services.DBusInterface object_interface;
    private Gee.HashMap<string, Bluetooth.Services.Adapter> adapters;
    private Gee.HashMap<string, Bluetooth.Services.Device> devices;

    public ObjectManager () {

    }

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
                    var powered = changed.lookup_value("Powered", new VariantType("b"));
                    if (powered != null) {
                        check_global_state ();
                    }
                });
            } catch (Error e) {
                debug ("Connecting to bluetooth adapter failed: %s", e.message);
            }
        } else if ("org.bluez.Device1" in param) {
            try {
                Bluetooth.Services.Device device = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                if (device.paired) {
                    lock (devices) {
                        devices.set (path, device);
                    }

                    device_added (device);
                }

                (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
                    var connected = changed.lookup_value("Connected", new VariantType("b"));
                    if (connected != null) {
                        check_global_state ();
                    }

                    var paired = changed.lookup_value("Paired", new VariantType("b"));
                    if (paired != null) {
                        if (device.paired) {
                            lock (devices) {
                                devices.set (path, device);
                            }

                            device_added (device);
                        } else {
                            lock (devices) {
                                devices.unset (path);
                            }

                            device_removed (device);
                        }
                    }
                });
            } catch (Error e) {
                debug ("Connecting to bluetooth device failed: %s", e.message);
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

    private void check_global_state () {
        global_state_changed (get_global_state (), get_connected ());
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

    public void set_global_state (bool state) {
        new Thread<void*> (null, () => {
            lock (devices) {
                foreach (var device in devices.values) {
                    if (device.connected) {
                        try {
                            device.disconnect ();
                        } catch (Error e) {
                            critical (e.message);
                        }
                    }
                }
            }

            lock (adapters) {
                foreach (var adapter in adapters.values) {
                    adapter.powered = state;
                }
            }

            if (settings != null) {
                settings.set_boolean ("bluetooth-enabled", state);
            }

            return null;
        });
    }
}
