"""Color-only extension for the existing wallpaper/Matugen pipeline."""
import configparser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def output_paths(home, config):
    return {
        'semantic.json': config / 'generated/palette.json',
        'gtk3.css': home / '.config/gtk-3.0/vladi-colors.css',
        'gtk4.css': home / '.config/gtk-4.0/vladi-colors.css',
        'kvantum.svg': home / '.config/Kvantum/vladi-dots/vladi-dots.svg',
        'kvantum.kvconfig': home / '.config/Kvantum/vladi-dots/vladi-dots.kvconfig',
        'kde.colors': home / '.local/share/color-schemes/vladi-dots.colors',
    }


def palette(data):
    roles = json.loads(data)
    fixed = json.loads((Path(__file__).parent / 'neutrals.json').read_text())
    for key, value in fixed.items():
        if roles.get(key) != value:
            raise ValueError('Fixed neutral changed: ' + key)
    for key, value in roles.items():
        if not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
            raise ValueError('Invalid palette role: ' + key)
    def blend(first, second, amount):
        a, b = (tuple(int(color[n:n+2], 16) for n in (1, 3, 5)) for color in (first, second))
        return '#' + ''.join(f'{round(x * (1 - amount) + y * amount):02x}' for x, y in zip(a, b))
    roles['selection_muted'] = blend(roles['background'], roles['accent'], 0.23)
    roles['accent_hover'] = blend(roles['accent'], roles['foreground'], 0.14)
    roles['warning'] = roles['accent_secondary']
    return roles


def render(template, roles):
    result = re.sub(r'\{\{role\.([a-z_]+)\}\}', lambda match: roles[match[1]], template)
    result = re.sub(r'\{\{rgb\.([a-z_]+)\}\}', lambda match: ','.join(str(int(roles[match[1]][i:i+2], 16)) for i in (1, 3, 5)), result)
    if '{{' in result:
        raise ValueError('Unresolved color token')
    return result.encode()


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        stream.write(data)
        temporary = Path(stream.name)
    temporary.chmod(0o644)
    temporary.replace(path)


def validate(rendered, temporary):
    import xml.etree.ElementTree as ET
    for name, version in [('gtk3.css', '3.0'), ('gtk4.css', '4.0')]:
        path = temporary / ('validate-' + name)
        path.write_bytes(rendered[name])
        result = subprocess.run([sys.executable, '-B', str(Path(__file__).parent / 'validate_css.py'), version, str(path)], capture_output=True, text=True, timeout=10)
        if result.returncode:
            raise ValueError(name + ': ' + result.stderr + result.stdout)
    ET.fromstring(rendered['kvantum.svg'])
    ET.fromstring(rendered['sddm-palette.xml'])


def patch_ini(text, section, values):
    """Preserve unrelated lines and font values exactly."""
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.strip() == '[' + section + ']'), None)
    if start is None:
        return text.rstrip() + '\n\n[' + section + ']\n' + ''.join(f'{k}={v}\n' for k, v in values.items())
    end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith('[')), len(lines))
    remaining = dict(values)
    for i in range(start + 1, end):
        stripped = lines[i].lstrip()
        if stripped.startswith(('#', ';')) or '=' not in stripped:
            continue
        key = stripped.split('=', 1)[0].strip()
        if key in remaining:
            lines[i] = key + '=' + str(remaining.pop(key)) + '\n'
    if remaining and end > 0 and not lines[end - 1].endswith('\n'):
        lines[end - 1] += '\n'
    lines[end:end] = [f'{key}={value}\n' for key, value in remaining.items()]
    return ''.join(lines)


def refresh(home, config):
    from live_refresh import refresh as native_refresh
    native_refresh(home, config)
