plug_files = files(
    'PairDialog.vala',
    'Plug.vala',
    'MainView.vala',
    'DeviceRow.vala',
    'Services/Agent.vala',
    'Services/Manager.vala',
    'Services/Device.vala',
    'Services/Adapter.vala'
)

switchboard_dep = dependency('switchboard-3')
switchboard_plugsdir = switchboard_dep.get_pkgconfig_variable('plugsdir', define_variable: ['libdir', libdir])

shared_module(
    meson.project_name(),
    plug_files,
    config_file,
    dependencies: [
        dependency('libadwaita-1', version: '>=1.4.0'),
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite-7', version: '>=7.4.0'),
        dependency('gtk4'),
        meson.get_compiler('vala').find_library('posix'),
        switchboard_dep
    ],
    install: true,
    install_dir : join_paths(switchboard_plugsdir, 'network')
)
