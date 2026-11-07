"""Validate GTK syntax without opening windows or loading both GI GTK versions."""
import sys
import gi
gi.require_version('Gtk', sys.argv[1])
from gi.repository import Gtk
provider = Gtk.CssProvider()
errors = []
provider.connect('parsing-error', lambda provider, section, error: errors.append(str(error)))
provider.load_from_path(sys.argv[2])
if errors:
    raise SystemExit('\n'.join(errors))
