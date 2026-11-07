"""Publish complete immutable GTK themes, then notify native toolkit backends."""
import configparser
import hashlib
import json
import os
from pathlib import Path
import signal

from vladi_theme import atomic_write, patch_ini


def nearest_accent(color):
    import colorsys
    swatches = {'blue': '#3584e4', 'teal': '#2190a4', 'green': '#3a944a',
                'yellow': '#c88800', 'orange': '#ed5b00', 'red': '#e62d42',
                'pink': '#d56199', 'purple': '#9141ac', 'slate': '#6f8396'}
    def hsv(value):
        return colorsys.rgb_to_hsv(*(int(value[n:n+2], 16) / 255 for n in (1, 3, 5)))
    hue, saturation, _ = hsv(color)
    if saturation < .12:
        return 'slate'
    def distance(name):
        delta = abs(hue - hsv(swatches[name])[0])
        return min(delta, 1 - delta)
    return min((name for name in swatches if name != 'slate'), key=distance)


def publish_gtk(home):
    css = [(home / f'.config/gtk-{v}.0/vladi-colors.css').read_bytes() for v in (3, 4)]
    digest = hashlib.sha256(b'vladi-native-theme-v1\0' + b'\0'.join(css)).hexdigest()[:20]
    name = 'vladi-dots-' + digest
    root = home / '.local/share/themes' / name
    resources = ('Adwaita/gtk-contained-dark.css', 'Default/gtk-dark.css')
    for version, data, resource in zip((3, 4), css, resources):
        content = ('@import url("resource:///org/gtk/libgtk/theme/' + resource + '");\n').encode() + data
        for variant in ('gtk.css', 'gtk-dark.css'):
            target = root / f'gtk-{version}.0' / variant
            if not target.exists() or target.read_bytes() != content:
                atomic_write(target, content)
    return name


def refresh(home, config):
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio, GLib

    roles = json.loads((config / 'generated/palette.json').read_bytes())
    theme = publish_gtk(home)
    files = [home / '.config/Kvantum/vladi-dots/vladi-dots.svg',
             home / '.config/Kvantum/vladi-dots/vladi-dots.kvconfig',
             home / '.local/share/color-schemes/vladi-dots.colors']
    generation = hashlib.sha256(theme.encode() + b''.join(p.read_bytes() for p in files)).hexdigest()
    state = home / '.local/state/vladi-theme/live-refresh.json'
    try:
        previous = json.loads(state.read_text())
    except (OSError, ValueError):
        previous = {}
    settings = Gio.Settings.new('org.gnome.desktop.interface')
    accent = nearest_accent(roles['accent'])
    if previous.get('generation') == generation and settings.get_string('gtk-theme') == theme and settings.get_string('accent-color') == accent:
        return

    generated = configparser.ConfigParser(interpolation=None)
    generated.optionxform = str
    generated.read(files[-1])
    target = home / '.config/kdeglobals'
    after = target.read_text() if target.exists() else ''
    for section in generated.sections():
        after = patch_ini(after, section, dict(generated[section]))
    current = configparser.ConfigParser(interpolation=None)
    current.read_string(after)
    style = 'kvantum-dark' if current.get('KDE', 'widgetStyle', fallback='kvantum') == 'kvantum' else 'kvantum'
    after = patch_ini(after, 'KDE', {'widgetStyle': style})
    atomic_write(target, after.encode())

    settings.delay()
    settings.set_string('gtk-theme', theme)
    settings.set_string('accent-color', accent)
    settings.apply()
    Gio.Settings.sync()
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    for kind in (2, 0):
        bus.emit_signal(None, '/KGlobalSettings', 'org.kde.KGlobalSettings',
                        'notifyChange', GLib.Variant('(ii)', (kind, 0)))
    bus.flush_sync(None)
    display = os.environ.get('WAYLAND_DISPLAY')
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if display and runtime:
        expected = [os.fsencode(f'WAYLAND_DISPLAY={display}'), os.fsencode(f'XDG_RUNTIME_DIR={runtime}')]
        for process in Path('/proc').iterdir():
            if process.name.isdecimal():
                try:
                    if process.stat().st_uid != os.getuid() or (process / 'comm').read_text().strip() != 'kitty':
                        continue
                    environment = (process / 'environ').read_bytes().split(b'\0')
                    if all(value in environment for value in expected):
                        os.kill(int(process.name), signal.SIGUSR1)
                except OSError:
                    pass
    atomic_write(state, (json.dumps({'generation': generation, 'gtk_theme': theme,
                 'libadwaita_accent': accent, 'qt_style': style}, indent=2) + '\n').encode())
