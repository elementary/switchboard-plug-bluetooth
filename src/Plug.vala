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

public class Bluetooth.Plug : Switchboard.Plug {
    private Gtk.Box box;
    private MainView main_view;
    private Services.ObjectManager manager;

    public Plug () {
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("network/bluetooth", null);
        Object (category: Category.NETWORK,
            code_name: "io.elementary.settings.bluetooth",
            display_name: _("Bluetooth"),
            description: _("Configure Bluetooth Settings"),
            icon: "bluetooth",
            supported_settings: settings);

        manager = Bluetooth.Services.ObjectManager.get_default ();
        manager.bind_property ("has-object", this, "can-show", GLib.BindingFlags.SYNC_CREATE);
    }

    public override Gtk.Widget get_widget () {
        if (box == null) {
            var headerbar = new Adw.HeaderBar () {
                show_title = false
            };
            headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

            main_view = new MainView () {
                vexpand = true
            };

            box = new Gtk.Box (VERTICAL, 0);
            box.append (headerbar);
            box.append (main_view);

            main_view.quit_plug.connect (() => hidden ());
        }

        return box;
    }

    public override void shown () {
        manager.register_agent.begin (main_view.get_root () as Gtk.Window);
        manager.set_global_state.begin (true); /* Also sets discoverable true and starts discovery */
    }

    public override void hidden () {
        Application.get_default ().hold ();
        manager.unregister_agent.begin ();
        manager.discoverable = false; /* Does not change is_powered or connections*/
        manager.stop_discovery.begin (() => {
            Application.get_default ().release ();
        });
    }

    public override void search_callback (string location) {

    }

    // 'search' returns results like ("Keyboard → Behavior → Duration", "keyboard<sep>behavior")
    public override async Gee.TreeMap<string, string> search (string search) {
        var search_results = new Gee.TreeMap<string, string> ((GLib.CompareDataFunc<string>)strcmp, (Gee.EqualDataFunc<string>)str_equal);
        /*search_results.set ("%s → %s".printf (display_name, _("General")), "");*/
        return search_results;
    }
}

public Switchboard.Plug get_plug (Module module) {
    debug ("Activating Bluetooth plug");
    var plug = new Bluetooth.Plug ();
    return plug;
}
