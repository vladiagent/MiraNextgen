#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import sys
import subprocess
from wallpaper_service import WallpaperService

EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp'}

def import_image(source, folder):
    from PIL import Image
    source = Path(source).expanduser().resolve(strict=True)
    if source.suffix.lower() not in EXTENSIONS:
        raise ValueError('Choose a PNG, JPEG or WebP image.')
    with Image.open(source) as image:
        image.verify()
    folder = Path(folder).expanduser().resolve()
    folder.mkdir(parents=True, exist_ok=True)
    if source.parent == folder:
        return source
    name, suffix = source.stem, source.suffix.lower()
    for count in range(10000):
        dest = folder / (name + (f' ({count})' if count else '') + suffix)
        try:
            with dest.open('xb') as out:
                try:
                    with source.open('rb') as src:
                        shutil.copyfileobj(src, out)
                except BaseException:
                    dest.unlink(missing_ok=True)
                    raise
            return dest
        except FileExistsError:
            continue
    raise RuntimeError('Too many files with this name.')

def listing(service, directory=None):
    settings = service.settings()
    folder = Path(settings.get('folder', '~/Pictures/Backgrounds')).expanduser()
    current = Path(settings.get('wallpaper', '')).expanduser()
    browsing = directory is not None
    location = Path(directory).expanduser().resolve(strict=True) if browsing else folder
    if not browsing:
        location.mkdir(parents=True, exist_ok=True)
    if not location.is_dir():
        raise ValueError('This folder does not exist.')
    items = []
    paths = location.iterdir() if browsing or settings.get('subfolders', 'false').lower() != 'true' else location.rglob('*')
    paths = sorted((p for p in paths if not p.name.startswith('.')), key=lambda p: (not p.is_dir(), p.name.casefold()))
    if not browsing and current.is_file() and current not in paths:
        paths.insert(0, current)
    for p in paths:
        if browsing and p.is_dir():
            items.append({'path':str(p),'name':p.name,'directory':True,'preview':'','selected':False})
        elif p.is_file() and p.suffix.lower() in EXTENSIONS:
            try:
                preview = service.thumbnail(p)
                items.append({'path':str(p),'name':p.stem,'directory':False,'preview':preview,'selected':p.resolve()==current.resolve()})
            except Exception:
                continue
    downloads = Path.home() / 'Downloads'
    return {'ok':True,'items':items,'folder':str(location),'parent':str(location.parent),
            'downloads':str(downloads) if downloads.is_dir() else '',
            'current':str(current),'library':str(folder),'browsing':browsing}

def main():
    service = WallpaperService()
    action = sys.argv[1] if len(sys.argv)>1 else 'list'
    if action == 'restore':
        service.restore()
        subprocess.run([str(Path.home() / '.local/bin/miraos-wallpaper-theme')], check=True)
        return {'ok': True}
    if action == 'list':
        return listing(service)
    if action == 'browse':
        return listing(service, sys.argv[2])
    if action == 'apply':
        settings=service.settings()
        service.choose(sys.argv[2], settings.get('fill','fill'))
        result=listing(service)
        result['message']='Wallpaper applied'
        return result
    if action == 'add':
        settings=service.settings()
        dest=import_image(sys.argv[2], settings.get('folder','~/Pictures/Backgrounds'))
        result=listing(service)
        result['message']='Added '+dest.name+' — select it to apply'
        return result
    raise ValueError('Unknown wallpaper action')

if __name__ == '__main__':
    try:
        print(json.dumps(main()))
    except Exception as error:
        print(json.dumps({'ok':False,'error':str(error)}))
        sys.exit(1)
