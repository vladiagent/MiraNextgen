#!/usr/bin/env python3
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

source = Path(__file__).resolve().parent / 'qt5'
if len(sys.argv) != 2:
    raise SystemExit('Usage: build-qt5-bridge.py OUTPUT.so')
output = Path(sys.argv[1]).resolve()
version = subprocess.check_output(['pkg-config', '--modversion', 'Qt5Gui'], text=True).strip()
headers = Path(subprocess.check_output(['pkg-config', '--variable=includedir', 'Qt5Gui'], text=True).strip())
flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt5Widgets', 'Qt5DBus'], text=True))
with tempfile.TemporaryDirectory(prefix='miraos-qt5-') as directory:
    build = Path(directory)
    subprocess.run(['moc-qt5', str(source / 'qt5-kde-bridge.cpp'), '-o', str(build / 'qt5-kde-bridge.moc')], check=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    includes = [headers / name / version / suffix for name in ('QtGui', 'QtCore') for suffix in ('', name)]
    subprocess.run(['g++', '-std=c++17', '-shared', '-fPIC', '-O2', '-I' + str(build),
                    *['-I' + str(path) for path in includes],
                    str(source / 'qt5-kde-bridge.cpp'), '-o', str(output), *flags], check=True)
