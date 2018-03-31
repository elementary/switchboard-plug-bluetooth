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

[DBus (name = "org.bluez.Device1")]
public interface Bluetooth.Services.Device : Object {
    public abstract void cancel_pairing () throws Error;
    public abstract async void connect () throws Error;
    public abstract void connect_profile (string UUID) throws Error;
    public abstract async void disconnect () throws Error;
    public abstract void disconnect_profile (string UUID) throws Error;
    public abstract async void pair () throws Error;

    public abstract string[] UUIDs { owned get; }
    public abstract bool blocked { owned get; set; }
    public abstract bool connected { owned get; }
    public abstract bool legacy_pairing { owned get; }
    public abstract bool paired { owned get; }
    public abstract bool trusted { owned get; set; }
    public abstract int16 RSSI { owned get; }
    public abstract ObjectPath adapter { owned get; }
    public abstract string address { owned get; }
    public abstract string alias { owned get; set; }
    public abstract string icon { owned get; }
    public abstract string modalias { owned get; }
    public abstract string name { owned get; }
    public abstract uint16 appearance { owned get; }
    public abstract uint32 @class { owned get; }
}
