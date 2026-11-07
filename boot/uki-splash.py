#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import struct
import subprocess
import sys
import tempfile

BASE = Path(__file__).resolve().parent
ARCH_SPLASH = Path('/usr/share/systemd/bootctl/splash-arch.bmp')
INSTALL_SPLASH = Path('/usr/local/share/miraos-dots/boot/splash.bmp')
PRESETS = Path('/etc/mkinitcpio.d')
EFI_VARS = Path('/sys/firmware/efi/efivars')
STATE = Path('/var/lib/miraos-dots/boot')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def u16(data, offset):
    return struct.unpack_from('<H', data, offset)[0]


def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]


def pe_splash(image, expected):
    require(image[:2] == b'MZ', 'Invalid EFI executable')
    pe = u32(image, 60)
    require(image[pe:pe + 4] == b'PE\0\0', 'Invalid EFI PE header')
    optional = pe + 24
    table = optional + u16(image, pe + 20)
    require(u16(image, optional) == 0x20B and u16(image, optional + 68) == 10,
            'Expected a PE32+ EFI application')
    require(not u32(image, optional + 144) and not u32(image, optional + 148),
            'The UKI is signed. Use your existing UKI signing workflow.')
    sections = {}
    for index in range(u16(image, pe + 6)):
        header = table + index * 40
        name = bytes(image[header:header + 8]).rstrip(b'\0')
        size = u32(image, header + 8)
        raw_size = u32(image, header + 16)
        offset = u32(image, header + 20)
        require(name not in sections, 'Duplicate PE section')
        sections[name] = (size, raw_size, offset)
    require({b'.linux', b'.initrd', b'.splash'} <= sections.keys(),
            'The EFI file is missing UKI sections')
    require(not {b'.pcrsig', b'.pcrpkey', b'.profile'} & sections.keys(),
            'The UKI has a PCR signature or multiple profiles. Use your existing UKI workflow.')
    size, raw_size, offset = sections[b'.splash']
    require(size == len(expected) and raw_size >= size and table <= offset
            and offset + raw_size <= len(image), 'Unexpected UKI splash section size')
    require(image[offset:offset + size] == expected, 'UKI splash differs from the expected bitmap')
    return offset, optional + 64


def patch_uki(image, before, after):
    require(len(before) == len(after), 'Splash bitmaps must have matching byte lengths')
    offset, checksum = pe_splash(image, before)
    updated = bytearray(image)
    updated[offset:offset + len(after)] = after
    if u32(image, checksum):
        struct.pack_into('<I', updated, checksum, 0)
        words = memoryview(updated)[:len(updated) & ~1].cast('H')
        total = sum(words) + (updated[-1] if len(updated) % 2 else 0)
        while total > 0xffff:
            total = (total & 0xffff) + (total >> 16)
        struct.pack_into('<I', updated, checksum, total + len(updated))
    pe_splash(updated, after)
    return updated


def find_presets():
    plans = []
    splash = str(ARCH_SPLASH)
    for preset in sorted(PRESETS.glob('*.preset')):
        contents = preset.read_text()
        active = re.search(r'^\s*PRESETS=\(([^\n]*)\)\s*$', contents, re.M)
        if active is None:
            continue
        updated = contents
        ukis = []
        for name in shlex.split(active[1]):
            if not re.fullmatch(r'\w+', name):
                continue
            options = re.search(rf'^(\s*{name}_options=["\'])([^\n]*)(["\'])\s*$', contents, re.M)
            if options is None or splash not in shlex.split(options[2]):
                continue
            require(shlex.split(options[2]).count(splash) == 1
                    and re.search(rf'(?:^| )--splash +{re.escape(splash)}(?: |$)', options[2]),
                    f'Unsupported splash assignment in {preset}')
            output = re.search(rf'^\s*{name}_uki=["\'](/[^"\'\n]+)["\']\s*$', contents, re.M)
            require(output is not None, f'Missing literal UKI path in {preset}')
            uki = Path(output[1])
            require(uki.parent in (Path('/boot/EFI/Linux'), Path('/efi/EFI/Linux'),
                                   Path('/boot/efi/EFI/Linux')) and uki.suffix.lower() == '.efi',
                    f'Unsupported UKI path in {preset}')
            require(not uki.is_symlink() and not preset.is_symlink(),
                    f'Refusing a symbolic link in {preset}')
            updated = updated.replace(options[0], options[0].replace(splash, str(INSTALL_SPLASH)), 1)
            ukis.append(uki)
        if ukis:
            plans.append((preset, contents.encode(), updated.encode(), ukis))
    require(plans, 'No active mkinitcpio UKI preset uses the Arch splash bitmap')
    return plans


def verify_environment():
    variables = list(EFI_VARS.glob('SecureBoot-*'))
    require(len(variables) == 1 and variables[0].read_bytes()[4:] == b'\0',
            'Secure Boot is enabled or unavailable. Use your existing UKI signing workflow.')
    for path in map(Path, ('/etc/crypttab', '/etc/crypttab.initramfs', '/etc/kernel/cmdline')):
        if path.exists():
            lines = [line for line in path.read_text().splitlines() if not line.lstrip().startswith('#')]
            require(not any('tpm2' in line.lower() for line in lines),
                    'A TPM-bound boot policy may depend on the current splash measurement.')


def replace(path, contents, mode):
    require(not path.is_symlink(), f'Refusing a symbolic link at {path}')
    descriptor, name = tempfile.mkstemp(prefix='.miraos-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            os.fchmod(handle.fileno(), mode)
            handle.write(contents)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
        descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    finally:
        Path(name).unlink(missing_ok=True)


def apply_changes(changes):
    applied = []
    try:
        for path, before, after, mode in changes:
            if before is None:
                require(not path.exists(), f'File appeared during installation: {path}')
            else:
                require(path.read_bytes() == before, f'File changed during operation: {path}')
            applied.append((path, before, mode))
            replace(path, after, mode)
    except BaseException:
        for path, before, mode in reversed(applied):
            if before is None:
                path.unlink(missing_ok=True)
            else:
                replace(path, before, mode)
        raise


def check_uki_path(path):
    require(path.is_file() and not path.is_symlink() and path.resolve() == path,
            f'Missing or unsupported UKI file: {path}')
    filesystem = subprocess.check_output(
        ['/usr/bin/findmnt', '-n', '-o', 'FSTYPE', '--target', str(path)], text=True).strip()
    require(filesystem == 'vfat', f'Expected a mounted FAT EFI partition for {path}')


def install(check):
    if STATE.is_dir():
        if check and os.geteuid() != 0:
            print('A MiraOS boot backup exists. Run check with sudo to validate the active files.')
            return
        verify_environment()
        if check:
            owned_changes()
            print('MiraOS boot branding is already installed and passed validation.')
        else:
            changes = owned_changes((BASE / 'miraos-splash.bmp').read_bytes())
            if changes:
                apply_changes(changes)
                print('Updated the MiraOS bitmap in the existing UKIs and future mkinitcpio builds.')
            else:
                print('MiraOS boot branding is already installed and passed validation.')
        return
    require(not STATE.exists() and not INSTALL_SPLASH.exists() and not INSTALL_SPLASH.is_symlink(),
            'A boot branding installation or rollback directory already exists')
    plans = find_presets()
    original = ARCH_SPLASH.read_bytes()
    replacement = (BASE / 'miraos-splash.bmp').read_bytes()
    require(original.startswith(b'BM') and replacement.startswith(b'BM')
            and len(original) == len(replacement)
            and u32(original, 2) == u32(replacement, 2) == len(original),
            'Invalid or incompatible boot bitmap')
    require(original != replacement, 'The replacement bitmap matches the original')
    for preset, _, _, ukis in plans:
        print(f'{preset}: {", ".join(map(str, ukis))}')
    if check and os.geteuid() != 0:
        print('Run check with sudo to validate the actual EFI images.')
        return
    verify_environment()
    changes = [(INSTALL_SPLASH, None, replacement, 0o644)]
    records = []
    seen = set()
    for preset, before, after, ukis in plans:
        for uki in ukis:
            require(uki not in seen, f'The same UKI appears in multiple presets: {uki}')
            seen.add(uki)
            check_uki_path(uki)
            old_image = uki.read_bytes()
            new_image = patch_uki(old_image, original, replacement)
            changes.append((uki, old_image, new_image, stat.S_IMODE(uki.stat().st_mode)))
        changes.append((preset, before, after, stat.S_IMODE(preset.stat().st_mode)))
        records.append({'preset': str(preset), 'before': before.decode(), 'after': after.decode(),
                        'ukis': list(map(str, ukis))})
    if check:
        print('Every existing EFI image and splash section passed validation.')
        return
    STATE.mkdir(mode=0o700, parents=True)
    (STATE / 'arch-splash.bmp').write_bytes(original)
    for path, before, _, _ in changes:
        if before is not None:
            (STATE / f'{path.name}.before').write_bytes(before)
    manifest = {'splash_sha256': hashlib.sha256(replacement).hexdigest(), 'presets': records}
    (STATE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    INSTALL_SPLASH.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    require(INSTALL_SPLASH.parent.resolve() == INSTALL_SPLASH.parent,
            f'Unexpected asset directory: {INSTALL_SPLASH.parent}')
    apply_changes(changes)
    (STATE / 'installed').touch()
    print('MiraOS splash installed for the existing UKIs and future mkinitcpio builds.')
    print(f'Boot backup: {STATE}')


def owned_changes(new_bitmap=None):
    require((STATE / 'installed').is_file(), f'No complete boot branding installation in {STATE}')
    manifest_path = STATE / 'manifest.json'
    manifest_before = manifest_path.read_bytes()
    manifest = json.loads(manifest_before)
    current = INSTALL_SPLASH.read_bytes()
    require(hashlib.sha256(current).hexdigest() == manifest['splash_sha256'],
            'The installed splash was modified. Restore it before uninstalling.')
    original = (STATE / 'arch-splash.bmp').read_bytes()
    require(ARCH_SPLASH.read_bytes() == original,
            'The system Arch bitmap changed. Review the boot backup and rebuild with mkinitcpio.')
    if new_bitmap is not None:
        require(new_bitmap.startswith(b'BM') and u32(new_bitmap, 2) == len(new_bitmap) == len(current),
                'Invalid or incompatible boot bitmap')
    replacement = original if new_bitmap is None else new_bitmap
    changes = []
    for record in manifest['presets']:
        preset = Path(record['preset'])
        require(preset.read_text() == record['after'], f'Boot preset was modified: {preset}')
        for name in record['ukis']:
            uki = Path(name)
            check_uki_path(uki)
            image = uki.read_bytes()
            changes.append((uki, image, patch_uki(image, current, replacement),
                            stat.S_IMODE(uki.stat().st_mode)))
        if new_bitmap is None:
            changes.append((preset, record['after'].encode(), record['before'].encode(),
                            stat.S_IMODE(preset.stat().st_mode)))
    if new_bitmap is not None:
        if new_bitmap == current:
            return []
        manifest['splash_sha256'] = hashlib.sha256(new_bitmap).hexdigest()
        manifest_after = (json.dumps(manifest, indent=2) + '\n').encode()
        changes.append((INSTALL_SPLASH, current, new_bitmap, 0o644))
        changes.append((manifest_path, manifest_before, manifest_after,
                        stat.S_IMODE(manifest_path.stat().st_mode)))
    return changes


def uninstall():
    verify_environment()
    apply_changes(owned_changes())
    INSTALL_SPLASH.unlink()
    (STATE / 'installed').unlink()
    backup = Path(tempfile.mkdtemp(prefix='boot-rollback-', dir=STATE.parent))
    STATE.rename(backup)
    print(f'Arch splash restored. The original backup is retained in {backup}.')


def main():
    parser = argparse.ArgumentParser(description='Manage the splash on existing Arch Linux UKIs.')
    parser.add_argument('operation', choices=('check', 'install', 'uninstall'))
    operation = parser.parse_args().operation
    require(operation == 'check' or os.geteuid() == 0, 'Run install or uninstall with sudo')
    if operation == 'uninstall':
        uninstall()
    else:
        install(check=operation == 'check')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, struct.error, subprocess.CalledProcessError) as error:
        sys.exit(f'Boot branding: {error}')
