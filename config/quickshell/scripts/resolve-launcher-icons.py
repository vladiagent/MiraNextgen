#!/usr/bin/env python3
"""Resolve installed theme icons once, never on a keystroke or frame.

The running Qt platform theme can return a generic icon for valid app names.
GTK's installed icon-theme lookup supplies actual local filenames; Quickshell
still owns desktop entry metadata, searching, launching and rendering.
"""
import json
from pathlib import Path
import sys
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

Gtk.init([])
theme = Gtk.IconTheme.get_default()
resolved = {}
for name in json.loads(sys.argv[1]):
    if not isinstance(name, str) or not name:
        continue
    if name.startswith('/') and Path(name).is_file():
        resolved[name] = str(Path(name))
        continue
    info = theme.lookup_icon(name, 64, Gtk.IconLookupFlags.FORCE_SIZE)
    if info and info.get_filename():
        resolved[name] = info.get_filename()
print(json.dumps(resolved), flush=True)
