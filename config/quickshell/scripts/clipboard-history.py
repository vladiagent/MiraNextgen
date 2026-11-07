#!/usr/bin/env python3
"""Private, event-driven cliphist adapter. Clipboard bytes never enter argv/logs."""
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import signal
import subprocess
import sys

os.umask(0o077)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
MAX_BYTES = 5 * 1024 * 1024
database = Path(os.environ.get('VLADI_CLIPBOARD_DB', os.environ.get(
    'CLIPHIST_DB_PATH', str(Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'cliphist/db'))))
binary = '/usr/bin/cliphist' if Path('/usr/bin/cliphist').exists() else shutil.which('cliphist') or str(Path.home() / '.local/bin/cliphist')

def command(action):
    return [binary, '-db-path', str(database), '-max-items', '500',
            '-max-dedupe-search', '500', '-preview-width', '512', action]

def emit(event, **data):
    print(json.dumps({'event': event, **data}, ensure_ascii=True), flush=True)

def run(action, data=None):
    result = subprocess.run(command(action), input=data, capture_output=True, timeout=12)
    if result.returncode:
        raise RuntimeError('Clipboard operation failed')
    return result.stdout

def mime(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'image/png'
    if data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    if data[:6] in (b'GIF87a', b'GIF89a'):
        return 'image/gif'
    if data.startswith(b'RIFF') and data[8:12] == b'WEBP':
        return 'image/webp'
    if data.startswith(b'BM'):
        return 'image/bmp'
    return ''

def store():
    # wl-paste recognizes x-kde-passwordManagerHint and sets this state.
    if os.environ.get('CLIPBOARD_STATE', 'data') != 'data':
        return
    data = sys.stdin.buffer.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        while sys.stdin.buffer.read(65536):
            pass
        return
    if not data:
        return
    try:
        run('store', data)
        emit('changed')
    except (OSError, RuntimeError, subprocess.TimeoutExpired):
        pass

def watch(parent_pid):
    import ctypes

    # Keep the watcher tied to this bridge even if Quickshell kills it on reload.
    set_parent_death_signal = 1
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(set_parent_death_signal, signal.SIGTERM, 0, 0, 0) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
    if os.getppid() != parent_pid:
        return
    os.execvp('wl-paste', ['wl-paste', '--watch', sys.executable, '-B',
                          str(Path(__file__).resolve()), '--store'])

class Bridge:
    def __init__(self):
        from gi.repository import GLib
        self.GLib = GLib
        self.loop = GLib.MainLoop()
        self.opened = False
        self.buffer = b''
        self.watch_buffer = b''
        self.watcher = None
        self.lock = None
        database.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        database.parent.chmod(0o700)
        if database.exists():
            database.chmod(0o600)
        runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'vladi-clipboard'
        runtime.mkdir(mode=0o700, exist_ok=True)
        if runtime.stat().st_uid != os.getuid():
            raise RuntimeError('Invalid clipboard runtime directory')
        runtime.chmod(0o700)
        key = hashlib.sha256((str(database) + os.environ.get('WAYLAND_DISPLAY', '')).encode()).hexdigest()[:20]
        self.lock = (runtime / (key + '.lock')).open('w')
        # A new QML generation waits for the previous watcher to exit.
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        self.watcher = subprocess.Popen([sys.executable, '-B', str(Path(__file__).resolve()),
                                         '--watch-parent', str(os.getpid())],
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        GLib.io_add_watch(self.watcher.stdout.fileno(), GLib.IO_IN | GLib.IO_HUP, self.changed)
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, self.request)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.stop)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.stop)
        emit('ready', available=True)

    def stop(self):
        self.loop.quit()
        return False

    def listing(self):
        if not self.opened:
            return
        if not database.exists():
            emit('entries', entries=[])
            return
        rows = []
        for line in run('list').decode('utf-8', errors='replace').splitlines():
            identifier, separator, preview = line.partition('\t')
            if separator and identifier.isdecimal():
                rows.append({'id': identifier, 'preview': preview,
                             'image': '[[ binary data ' in preview and any(
                                 kind in preview.lower() for kind in ['png', 'jpeg', 'jpg', 'webp', 'gif', 'bmp'])})
        emit('entries', entries=rows[:500])

    def changed(self, fd, condition):
        if condition & self.GLib.IO_HUP:
            emit('unavailable')
            return False
        data = os.read(fd, 65536)
        self.watch_buffer += data
        while b'\n' in self.watch_buffer:
            line, self.watch_buffer = self.watch_buffer.split(b'\n', 1)
            if line and self.opened:
                try:
                    self.listing()
                except (OSError, RuntimeError, subprocess.TimeoutExpired):
                    emit('error', message='Could not read clipboard history.')
        return True

    def request(self, fd, condition):
        if condition & self.GLib.IO_HUP:
            return self.stop()
        data = os.read(fd, 65536)
        if not data:
            return self.stop()
        self.buffer += data
        if len(self.buffer) > 65536:
            return self.stop()
        while b'\n' in self.buffer:
            line, self.buffer = self.buffer.split(b'\n', 1)
            try:
                request = json.loads(line)
                action = request.get('command')
                if action == 'open':
                    self.opened = True
                    self.listing()
                elif action == 'close':
                    self.opened = False
                elif action == 'clear':
                    run('wipe')
                    self.listing()
                elif action in ('copy', 'delete', 'thumbnail'):
                    identifier = str(request.get('id', ''))
                    if not identifier.isdecimal():
                        raise ValueError()
                    key = (identifier + '\t\n').encode()
                    if action == 'delete':
                        run('delete', key)
                        self.listing()
                    else:
                        content = run('decode', key)
                        if len(content) > MAX_BYTES:
                            raise ValueError()
                        kind = mime(content)
                        if action == 'copy':
                            options = ['wl-copy'] + (['--type', kind] if kind else ['--type', 'text/plain;charset=utf-8'])
                            subprocess.run(options, input=content, stdout=subprocess.DEVNULL,
                                           stderr=subprocess.DEVNULL, check=True, timeout=8)
                            emit('copied')
                        elif kind and self.opened:
                            self.thumbnail(identifier, content)
            except (ValueError, TypeError, OSError, RuntimeError, subprocess.SubprocessError):
                emit('error', message='The clipboard operation could not be completed.')
        return True

    def thumbnail(self, identifier, content):
        try:
            import gi
            gi.require_version('GdkPixbuf', '2.0')
            from gi.repository import GdkPixbuf
            loader = GdkPixbuf.PixbufLoader.new()
            def resize(image_loader, width, height):
                scale = min(1, 96 / max(width, height))
                image_loader.set_size(max(1, int(width * scale)), max(1, int(height * scale)))
            loader.connect('size-prepared', resize)
            loader.write(content)
            loader.close()
            pixbuf = loader.get_pixbuf()
            success, data = pixbuf.save_to_bufferv('png', [], [])
            if success:
                emit('thumbnail', id=identifier, source='data:image/png;base64,' + base64.b64encode(data).decode())
        except Exception:
            pass

    def close(self):
        if self.watcher:
            self.watcher.terminate()
            try:
                self.watcher.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.watcher.kill()
                self.watcher.wait()
        if self.lock:
            self.lock.close()

if __name__ == '__main__':
    if '--store' in sys.argv:
        store()
    elif len(sys.argv) == 3 and sys.argv[1] == '--watch-parent':
        watch(int(sys.argv[2]))
    else:
        bridge = None
        try:
            bridge = Bridge()
            bridge.loop.run()
        except (OSError, RuntimeError):
            emit('error', message='Clipboard history is unavailable. Check cliphist and wl-clipboard.')
        finally:
            if bridge:
                bridge.close()
