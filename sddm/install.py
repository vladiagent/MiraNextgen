import argparse
import configparser
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import stat
import tempfile

THEME = 'miraos-dots'
FILES = ('Main.qml', 'Theme.qml', 'Action.qml', 'Selector.qml', 'Label.qml',
         'qmldir', 'metadata.desktop', 'theme.conf')
SELECTION = b'[Theme]\nCurrent=miraos-dots\n'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def system_directory(path):
    if not path.exists() and not path.is_symlink():
        system_directory(path.parent)
        path.mkdir(mode=0o755)
    status = path.lstat()
    require(stat.S_ISDIR(status.st_mode) and status.st_uid == 0 and not status.st_mode & 0o022,
            f'Unsafe system directory: {path}')


def read_owned(path):
    try:
        status = path.lstat()
    except FileNotFoundError:
        return None
    require(stat.S_ISREG(status.st_mode) and status.st_uid == 0 and not status.st_mode & 0o022,
            f'Unsafe system file: {path}')
    return path.read_bytes()


def atomic_write(path, data, mode=0o644):
    if data is None:
        path.unlink(missing_ok=True)
        return
    fd, name = tempfile.mkstemp(prefix='.miraos-', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            os.fchmod(stream.fileno(), mode)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def remove_empty(path):
    try:
        path.rmdir()
    except OSError:
        pass


def check_selection(root, snippet, theme_root):
    files = sorted((root / 'usr/lib/sddm/sddm.conf.d').glob('*.conf'))
    local = sorted((root / 'etc/sddm.conf.d').glob('*.conf'))
    files.extend(path for path in local if path < snippet)
    files.append(snippet)
    files.extend(path for path in local if path > snippet)
    files.append(root / 'etc/sddm.conf')
    current, source, theme_dir = None, None, '/usr/share/sddm/themes'
    for path in files:
        settings = configparser.ConfigParser(interpolation=None, strict=False)
        if path == snippet:
            settings.read_string(SELECTION.decode())
        elif path.is_file():
            settings.read(path)
        else:
            continue
        if settings.has_option('Theme', 'Current'):
            current = settings.get('Theme', 'Current')
            source = path
        theme_dir = settings.get('Theme', 'ThemeDir', fallback=theme_dir)
    require(current == THEME, f'SDDM theme selection is overridden by {source}. Resolve its [Theme] Current setting and retry.')
    require(root / theme_dir.lstrip('/') == theme_root,
            f'SDDM uses a custom ThemeDir ({theme_dir}). Resolve it before installing.')


def apply(root, account, operation, source):
    state = root / 'var/lib/miraos-dots'
    manifest_path = state / 'sddm-install.json'
    if operation == 'uninstall' and not manifest_path.exists() and not manifest_path.is_symlink():
        print('No MiraOS SDDM installation record.')
        return
    system_directory(state)
    assets = state / 'sddm'
    descriptor = os.open(state / '.sddm-install.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        manifest_data = read_owned(manifest_path)
        record = json.loads(manifest_data) if manifest_data else None
        theme_root = root / 'usr/share/sddm/themes'
        snippet = root / 'etc/sddm.conf.d/99-miraos-dots.conf'
        target = theme_root / THEME
        if operation == 'uninstall' and not record:
            print('No MiraOS SDDM installation record.')
            return
        system_directory(theme_root)
        system_directory(snippet.parent)
        paths = {name: target / name for name in FILES}
        paths['selection'] = snippet
        if record:
            require(record.get('uid') == account.pw_uid and set(record.get('files', {})) == set(paths),
                    'SDDM installation record belongs to another user or version.')
        if target.exists() or target.is_symlink():
            require(record is not None, f'SDDM theme directory is already in use: {target}')
            system_directory(target)
        before = {name: read_owned(path) for name, path in paths.items()}
        for name, data in before.items():
            if data is not None:
                require(record is not None and record['files'][name] == digest(data),
                        f'Existing or modified SDDM file needs manual review: {paths[name]}')
        if operation == 'install':
            require((root / 'usr/bin/sddm-greeter-qt6').is_file(), 'Install the Qt 6 SDDM greeter first.')
            check_selection(root, snippet, theme_root)
            after = {name: (source / name).read_bytes() for name in FILES}
            after['selection'] = SELECTION
        else:
            after = dict.fromkeys(paths)
        created_theme = operation == 'install' and not target.exists()
        created_assets = operation == 'install' and not assets.exists() and not assets.is_symlink()
        changed = []
        try:
            if created_theme:
                target.mkdir(mode=0o755)
            if created_assets:
                assets.mkdir(mode=0o755)
                os.chown(assets, account.pw_uid, account.pw_gid)
            if operation == 'install':
                status = assets.lstat()
                require(stat.S_ISDIR(status.st_mode) and status.st_uid == account.pw_uid,
                        f'SDDM asset directory is owned by another user: {assets}')
            for name, data in after.items():
                if before[name] != data:
                    atomic_write(paths[name], data)
                    changed.append(name)
            manifest = None if operation == 'uninstall' else {
                'uid': account.pw_uid, 'files': {name: digest(data) for name, data in after.items()}}
            atomic_write(manifest_path, None if manifest is None else
                         (json.dumps(manifest, indent=2) + '\n').encode(), 0o600)
        except BaseException:
            for name in reversed(changed):
                atomic_write(paths[name], before[name])
            if created_theme:
                remove_empty(target)
            if created_assets:
                remove_empty(assets)
            raise
        if operation == 'uninstall':
            remove_empty(target)
            remove_empty(assets)
            if assets.is_dir():
                print(f'Previously published greeter images and palettes remain in {assets}.')
            print('MiraOS SDDM selection and owned theme files removed.')
        else:
            print('MiraOS SDDM theme installed. It takes effect at the next greeter start.')
    finally:
        os.close(descriptor)


def main():
    parser = argparse.ArgumentParser(description='Install or remove the MiraOS SDDM theme.')
    parser.add_argument('operation', choices=('install', 'uninstall'))
    parser.add_argument('user')
    args = parser.parse_args()
    require(os.geteuid() == 0, 'Administrator authentication is required.')
    account = pwd.getpwnam(args.user)
    require(account.pw_uid >= 1000 and account.pw_uid != 65534, 'Choose a regular desktop user.')
    apply(Path('/'), account, args.operation, Path(__file__).resolve().parent / 'theme')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, configparser.Error) as error:
        raise SystemExit(f'SDDM: {error}')
