project(
    'bluetooth',
    'vala', 'c',
    version: '2.2.1'
)

gettext_name = meson.project_name() + '-plug'
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    language:'c'
)

subdir('data')
subdir('src')
subdir('po')
