"""Waypaper integration shared by the wallpaper picker and session startup."""
import configparser
import contextlib
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

FIT_MAP = {'fill': 'crop', 'fit': 'fit', 'stretch': 'stretch', 'center': 'no'}


def atomic_write(path: Path, data: bytes, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_DIRECTORY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)


def patch_ini(text: str, section: str, updates: dict[str, str]) -> str:
    """Patch named keys while retaining unrelated sections, comments and formatting."""
    remaining = dict(updates)
    result = []; inside = False; found = False
    for line in text.splitlines(keepends=True):
        match = re.match(r'\s*\[([^]]+)\]', line)
        if match:
            if inside:
                result.extend(f'{key} = {value}\n' for key, value in remaining.items()); remaining.clear()
            inside = match.group(1) == section
            found |= inside
        key = re.match(r'^([ \t]*)([^#;\s][^=]*?)([ \t]*=[ \t]*)(.*?)(\r?\n)?$', line)
        if inside and key and key.group(2).strip() in remaining:
            name = key.group(2).strip(); value = remaining.pop(name)
            if '\n' in value or '\r' in value: raise ValueError('Invalid configuration value')
            line = key.group(1) + key.group(2) + key.group(3) + value + (key.group(5) or '\n')
        result.append(line)
    if not found: result.append('\n[' + section + ']\n')
    if remaining:
        if result and not result[-1].endswith('\n'): result.append('\n')
        result.extend(f'{key} = {value}\n' for key, value in remaining.items())
    return ''.join(result)


class WallpaperService:
    def __init__(self, root=None, cache=None):
        self.root = root or Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))
        self.config = self.root/'waypaper/config.ini'
        self.cache = cache or Path(os.environ.get('XDG_CACHE_HOME', str(Path.home()/'.cache')))/'miraos-wallpapers'

    def settings(self):
        parser = configparser.ConfigParser(interpolation=None)
        if not self.config.exists(): raise RuntimeError('Waypaper configuration was not found')
        parser.read(self.config)
        values = dict(parser['Settings'])
        if values.get('backend') not in ('awww','swww'): raise RuntimeError('Waypaper backend changed. This installation supports the detected awww/swww backend.')
        return values

    def run(self, args, timeout=15):
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        if result.returncode: raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f'{args[0]} failed')
        return result.stdout

    def current_path(self, values):
        try:
            output = self.run([values['backend'], 'query'], timeout=3)
            match = re.search(r'currently displaying: image: (.+)', output)
            if match: return Path(match.group(1).strip())
        except Exception: pass
        return Path(values.get('wallpaper','')).expanduser()

    def thumbnail(self, path, large=False):
        from PIL import Image, ImageOps
        path = Path(path)
        if not path.is_file(): return ''
        stat = path.stat()
        digest = hashlib.sha256(f'{path.resolve()}:{stat.st_mtime_ns}:{stat.st_size}:{large}'.encode()).hexdigest()
        target = self.cache/'thumbnails'/f'{digest}.png'
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(path) as image:
                if image.width*image.height > 120_000_000: raise ValueError('Image exceeds the supported dimensions')
                image = ImageOps.exif_transpose(image)
                image.thumbnail((1440,900) if large else (420,270))
                image.convert('RGB').save(target, 'PNG')
        return target.as_uri()

    def apply_image(self, path, fit, values=None):
        values = values or self.settings()
        if fit not in FIT_MAP: raise ValueError('Unsupported wallpaper fit mode')
        path=Path(path).expanduser().resolve(strict=True)
        if path.suffix.lower() not in ('.png','.jpg','.jpeg','.webp'): raise ValueError('Choose a PNG, JPEG or WebP image')
        self.thumbnail(path)  # Validate decoding before changing the desktop.
        color=values.get('color','#000000').lstrip('#')
        if not re.fullmatch('[0-9a-fA-F]{6}([0-9a-fA-F]{2})?',color): color='000000'
        args=[values['backend'],'img',str(path),'--resize',FIT_MAP[fit],'--fill-color',color]
        for flag, key, default in (
            ('--transition-type', 'swww_transition_type', 'center'),
            ('--transition-duration', 'swww_transition_duration', '2'),
            ('--transition-fps', 'swww_transition_fps', '60'),
            ('--transition-step', 'swww_transition_step', '63'),
            ('--transition-angle', 'swww_transition_angle', '0'),
            ('--filter', 'swww_filter', 'Lanczos3'),
        ):
            args += [flag, str(values.get(key, default))]
        monitor=values.get('monitors','All')
        if monitor != 'All': args += ['--outputs',monitor]
        self.ensure_backend(values['backend'])
        self.run(args)
        return path

    def choose(self, path, fit):
        values=self.settings(); before=self.config.read_bytes(); previous=self.current_path(values)
        path=self.apply_image(path,fit,values)
        try:
            backup=self.config.parent/'backups'/(time.strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
            backup.mkdir(parents=True); shutil.copy2(self.config,backup/'config.ini')
            if self.config.read_bytes()!=before: raise RuntimeError('Waypaper settings changed during the operation; try again')
            updated=patch_ini(before.decode(),'Settings',{'wallpaper':str(path),'fill':fit})
            atomic_write(self.config,updated.encode())
        except Exception:
            if previous.is_file():
                with contextlib.suppress(Exception): self.apply_image(previous,values.get('fill','fill'),values)
            raise
        return str(path)

    def ensure_backend(self, backend):
        try:
            self.run([backend, 'query'], timeout=2)
        except (RuntimeError, OSError, subprocess.TimeoutExpired):
            subprocess.Popen([backend + '-daemon'], stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            deadline = time.monotonic() + 5
            while True:
                try:
                    self.run([backend, 'query'], timeout=2)
                    break
                except (RuntimeError, OSError, subprocess.TimeoutExpired):
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(0.1)

    def restore(self):
        values = self.settings()
        path = Path(values.get('wallpaper', '')).expanduser()
        if path.is_file():
            self.apply_image(path, values.get('fill', 'fill'), values)
