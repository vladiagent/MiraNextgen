#!/usr/bin/env python3
"""Non-secret session integration. Passwords never enter this process."""
import argparse
import json
import os
from pathlib import Path
import pwd
import socket
import stat
import sys
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

def emit(event, **data):
    print(json.dumps({'event': event, **data}), flush=True)

class SessionBridge:
    def __init__(self, isolated=False):
        self.isolated = isolated
        self.secure = False
        self.pending = []
        self.clients = {}
        self.session = None
        self.manager = None
        self.loop = GLib.MainLoop()
        account = pwd.getpwuid(os.getuid())
        avatar = next((p.as_uri() for p in [Path('/var/lib/AccountsService/icons') / account.pw_name,
                       Path(account.pw_dir) / '.face.icon', Path(account.pw_dir) / '.face'] if p.is_file()), '')
        emit('identity', account=account.pw_name, name=account.pw_gecos.split(',')[0] or account.pw_name,
             avatar=avatar, host=socket.gethostname())
        if not isolated:
            self.connect_logind()
            self.listen()
        else:
            emit('capabilities', actions={})
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.stdin_ready)
        emit('ready')

    def connect_logind(self):
        try:
            DBusGMainLoop(set_as_default=True)
            self.bus = dbus.SystemBus()
            self.manager = dbus.Interface(self.bus.get_object('org.freedesktop.login1', '/org/freedesktop/login1'), 'org.freedesktop.login1.Manager')
            sid = os.environ.get('XDG_SESSION_ID', '')
            candidates = [str(self.manager.GetSession(sid))] if sid else []
            if not candidates:
                candidates = [str(row[4]) for row in self.manager.ListSessions() if int(row[1]) == os.getuid()]
            for path in candidates:
                obj = self.bus.get_object('org.freedesktop.login1', path)
                props = dbus.Interface(obj, 'org.freedesktop.DBus.Properties')
                uid = int(props.Get('org.freedesktop.login1.Session', 'User')[0])
                kind = str(props.Get('org.freedesktop.login1.Session', 'Type'))
                if uid == os.getuid() and kind == 'wayland':
                    self.session = dbus.Interface(obj, 'org.freedesktop.login1.Session')
                    self.bus.add_signal_receiver(lambda: emit('lock', reason='session'), signal_name='Lock', dbus_interface='org.freedesktop.login1.Session', path=path)
                    break
            actions = {name: str(getattr(self.manager, method)()) == 'yes' for name, method in
                       [('suspend', 'CanSuspend'), ('reboot', 'CanReboot'), ('shutdown', 'CanPowerOff')]}
            emit('capabilities', actions=actions)
        except dbus.DBusException:
            emit('capabilities', actions={})
            emit('error', message='Session power controls are unavailable. Password locking remains available.')

    def set_locked(self, secure):
        self.secure = secure
        if self.session:
            try:
                self.session.SetLockedHint(secure)
            except dbus.DBusException:
                pass
        if secure:
            for connection in self.pending:
                self.reply(connection, {'secure': True})
            self.pending.clear()

    def run_power(self, action):
        if self.isolated or not self.manager:
            return
        method = {'suspend': 'Suspend', 'reboot': 'Reboot', 'shutdown': 'PowerOff'}.get(action)
        if method:
            getattr(self.manager, method)(False, reply_handler=lambda: None,
                error_handler=lambda error: emit('error', message='The requested power action was not permitted.'))

    def listen(self):
        runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid())))
        directory = runtime / 'vladi-lock'
        directory.mkdir(mode=0o700, exist_ok=True)
        info = directory.lstat()
        if info.st_uid != os.getuid() or not stat.S_ISDIR(info.st_mode):
            raise RuntimeError('Invalid lock-control directory')
        directory.chmod(0o700)
        self.path = directory / 'session.sock'
        if self.path.exists():
            old = self.path.lstat()
            if old.st_uid != os.getuid() or not stat.S_ISSOCK(old.st_mode):
                raise RuntimeError('Invalid lock-control socket')
            self.path.unlink()
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(str(self.path))
        self.path.chmod(0o600)
        self.inode = self.path.stat().st_ino
        self.server.listen(8)
        self.server.setblocking(False)
        GLib.io_add_watch(self.server.fileno(), GLib.IO_IN, lambda channel, condition: self.accept(self.server, condition))

    def accept(self, source, condition):
        connection, _ = self.server.accept()
        connection.setblocking(False)
        self.clients[connection] = b''
        GLib.io_add_watch(connection.fileno(), GLib.IO_IN | GLib.IO_HUP, lambda channel, condition, peer=connection: self.request(peer, condition))
        return True

    def request(self, connection, condition):
        if condition & GLib.IO_HUP:
            self.clients.pop(connection, None)
            connection.close()
            return False
        try:
            data = self.clients[connection] + connection.recv(1024)
            if len(data) > 1024:
                raise ValueError()
            self.clients[connection] = data
            if b'\n' not in data:
                return True
            request = json.loads(data.split(b'\n', 1)[0])
            if set(request) != {'command'}:
                raise ValueError()
            command = request['command']
            if command == 'status':
                self.reply(connection, {'secure': self.secure})
            elif command == 'lock':
                if self.secure:
                    self.reply(connection, {'secure': True})
                else:
                    self.pending.append(connection)
                    emit('lock', reason='request')
            elif command == 'suspend':
                self.reply(connection, {'requested': True})
                self.run_power('suspend')
            else:
                raise ValueError()
        except (ValueError, OSError, KeyError, TypeError):
            self.reply(connection, {'error': 'Invalid lock request'})
        return False

    def reply(self, connection, data):
        try:
            connection.sendall((json.dumps(data) + '\n').encode())
        except OSError:
            pass
        self.clients.pop(connection, None)
        connection.close()

    def stdin_ready(self, source, condition):
        if condition & GLib.IO_HUP:
            self.loop.quit()
            return False
        line = sys.stdin.readline(2048)
        if not line:
            self.loop.quit()
            return False
        try:
            message = json.loads(line)
            if message.get('command') == 'locked' and isinstance(message.get('secure'), bool):
                self.set_locked(message['secure'])
            elif message.get('command') == 'power' and message.get('action') in ('suspend', 'reboot', 'shutdown'):
                self.run_power(message['action'])
        except (ValueError, TypeError):
            pass
        return True

    def close(self):
        if not self.isolated:
            self.server.close()
            try:
                if self.path.stat().st_ino == self.inode:
                    self.path.unlink()
            except FileNotFoundError:
                pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--no-session-controls', action='store_true', help='Isolated compositor tests only; never bypasses PAM or session locking.')
    args = parser.parse_args()
    bridge = SessionBridge(args.no_session_controls)
    try:
        bridge.loop.run()
    finally:
        bridge.close()
