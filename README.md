# Switchboard Bluetooth Plug
[![l10n](https://l10n.elementary.io/widgets/switchboard/switchboard-plug-bluetooth/svg-badge.svg)](https://l10n.elementary.io/projects/switchboard/switchboard-plug-bluetooth)

![screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libgranite-dev >= 5.2.4
* libgtk-3-dev
* libswitchboard-2.0-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
