#!/usr/bin/env python
"""Publish only image and validated color data; never run as root."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageOps

COLOR_NAMES = ('background', 'surface', 'surface_variant', 'primary', 'secondary',
               'tertiary', 'on_surface', 'on_surface_variant', 'error', 'warning')


def validate_palette(data):
    if len(data) > 16384 or b'<!' in data:
        raise ValueError('Invalid palette data')
    tree = ET.fromstring(data)
    if tree.tag != 'theme' or len(tree) != 1 or tree[0].tag != 'palette':
        raise ValueError('Invalid palette structure')
    palette = tree[0]
    if sorted(child.tag for child in palette) != sorted(COLOR_NAMES):
        raise ValueError('Palette must contain exactly the expected semantic colors')
    for element in palette:
        if len(element) or element.attrib or not re.fullmatch(r'#[0-9a-fA-F]{6}', element.text or ''):
            raise ValueError('Invalid semantic color: ' + element.tag)
    return {element.tag: element.text.lower() for element in palette}


def publish(wallpaper, palette_file, destination):
    if os.geteuid() == 0:
        raise ValueError('Publish assets as the desktop user, not root')
    wallpaper = wallpaper.expanduser().resolve(strict=True)
    data = palette_file.read_bytes()
    validate_palette(data)
    if not destination.is_dir():
        raise FileNotFoundError('SDDM asset directory is not installed yet')
    image_hash = hashlib.sha256(wallpaper.read_bytes()).hexdigest()
    signature = hashlib.sha256(data + image_hash.encode() + b'png-v1').hexdigest()
    name = 'generation-' + signature[:20]
    generation = destination / name
    with (destination / '.publish.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not generation.is_dir():
            with tempfile.TemporaryDirectory(prefix='.build-', dir=destination) as temporary:
                temporary = Path(temporary)
                with Image.open(wallpaper) as image:
                    image = ImageOps.exif_transpose(image)
                    image.thumbnail((7680, 4320), Image.Resampling.LANCZOS)
                    image.convert('RGB').save(temporary / 'wallpaper.png', optimize=True)
                (temporary / 'palette.xml').write_bytes(data)
                (temporary / 'manifest.json').write_text(json.dumps({'signature': signature, 'wallpaper_sha256': image_hash}, indent=2) + '\n')
                for path in temporary.iterdir():
                    path.chmod(0o644)
                temporary.chmod(0o755)
                temporary.rename(generation)
        link = destination / ('.current-' + str(os.getpid()))
        try:
            link.symlink_to(name)
            link.replace(destination / 'current')
        finally:
            link.unlink(missing_ok=True)
        old = sorted((p for p in destination.glob('generation-*') if p.is_dir() and not p.is_symlink()),
                     key=lambda p: p.stat().st_mtime_ns, reverse=True)
        retained = {generation, *old[:3]}
        for path in old:
            if path not in retained and re.fullmatch(r'generation-[0-9a-f]{20}', path.name):
                shutil.rmtree(path)
    return generation


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--wallpaper', type=Path, required=True)
    parser.add_argument('--palette', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path('/var/lib/miraos-dots/sddm'))
    args = parser.parse_args()
    try:
        published = publish(args.wallpaper, args.palette, args.destination)
        print('SDDM wallpaper and palette synchronized: ' + published.name)
    except FileNotFoundError as error:
        print(str(error), file=sys.stderr)
        return 3
    except (OSError, ValueError, Image.DecompressionBombError) as error:
        print('SDDM asset sync failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
