# Bluetooth Settings
[![Translation status](https://l10n.elementary.io/widgets/switchboard/-/switchboard-plug-bluetooth/svg-badge.svg)](https://l10n.elementary.io/engage/switchboard/?utm_source=widget)

![screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libadwaita-1-dev >=1.4.0
* libgranite-7-dev
* libgtk-4-dev
* libswitchboard-3-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
