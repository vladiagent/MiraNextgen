#!/usr/bin/env python
"""BlueZ agent for one requested pairing; JSON prompts and responses on stdio."""
import json
import re
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

AGENT_PATH = '/org/quickshell/BarPairing'

class Rejected(dbus.DBusException):
    _dbus_error_name = 'org.bluez.Error.Rejected'

def emit(kind, **values):
    print(json.dumps(dict(kind=kind, **values)), flush=True)

class PairingAgent(dbus.service.Object):
    def __init__(self, bus, device_path, loop):
        super().__init__(bus, AGENT_PATH)
        self.device_path = device_path
        self.loop = loop
        self.pending = None
        self.serial = 0
        self.finished = False
        self.failed = False
        self.device = dbus.Interface(bus.get_object('org.bluez', device_path), 'org.bluez.Device1')
        self.properties = dbus.Interface(bus.get_object('org.bluez', device_path), 'org.freedesktop.DBus.Properties')

    def check_device(self, path):
        if str(path) != self.device_path:
            raise Rejected('This agent only handles the selected device')

    def prompt(self, path, kind, reply, error, **values):
        self.check_device(path)
        if self.pending:
            raise Rejected('Another pairing prompt is already pending')
        self.serial += 1
        self.pending = (self.serial, kind, reply, error)
        emit(kind, id=self.serial, **values)

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Release(self):
        self.finish(False, 'Bluetooth pairing agent was released')

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='s', async_callbacks=('reply', 'error'))
    def RequestPinCode(self, path, reply, error):
        self.prompt(path, 'pin', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='u', async_callbacks=('reply', 'error'))
    def RequestPasskey(self, path, reply, error):
        self.prompt(path, 'passkey', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='')
    def DisplayPinCode(self, path, pin):
        self.check_device(path)
        emit('display', code=str(pin), entered=0)

    @dbus.service.method('org.bluez.Agent1', in_signature='ouq', out_signature='')
    def DisplayPasskey(self, path, passkey, entered):
        self.check_device(path)
        emit('display', code=f'{int(passkey):06d}', entered=int(entered))

    @dbus.service.method('org.bluez.Agent1', in_signature='ou', out_signature='', async_callbacks=('reply', 'error'))
    def RequestConfirmation(self, path, passkey, reply, error):
        self.prompt(path, 'confirm', reply, error, code=f'{int(passkey):06d}')

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='', async_callbacks=('reply', 'error'))
    def RequestAuthorization(self, path, reply, error):
        self.prompt(path, 'authorize', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='', async_callbacks=('reply', 'error'))
    def AuthorizeService(self, path, uuid, reply, error):
        self.prompt(path, 'authorize', reply, error, service=str(uuid))

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Cancel(self):
        if self.pending:
            _, _, _, error = self.pending
            self.pending = None
            error(Rejected('Pairing canceled'))
        emit('clear')

    def respond(self, message):
        if message.get('action') == 'cancel':
            self.cancel()
            return
        if not self.pending or message.get('action') != 'respond':
            return
        serial, kind, reply, error = self.pending
        if message.get('id') != serial:
            return
        value = message.get('value')
        if kind == 'pin':
            if not isinstance(value, str) or not 1 <= len(value) <= 16:
                emit('validation', message='Enter a PIN containing 1–16 characters.')
                return
        elif kind == 'passkey':
            if not isinstance(value, str) or not re.fullmatch(r'[0-9]{1,6}', value):
                emit('validation', message='Enter a numeric passkey containing up to 6 digits.')
                return
            value = dbus.UInt32(int(value))
        elif value is not True:
            self.pending = None
            error(Rejected('Pairing rejected by user'))
            self.cancel()
            return
        self.pending = None
        reply(value) if kind in ('pin', 'passkey') else reply()
        emit('clear')

    def cancel(self):
        self.Cancel()
        self.device.CancelPairing(reply_handler=lambda: None, error_handler=lambda _: None)
        self.finish(False, 'Pairing canceled')

    def paired(self):
        self.properties.Set('org.bluez.Device1', 'Trusted', dbus.Boolean(True),
                            reply_handler=self.connect_device, error_handler=self.connection_error)

    def connect_device(self):
        emit('status', message='Paired. Connecting…')
        self.device.Connect(reply_handler=lambda: self.finish(True, 'Connected'),
                            error_handler=self.connection_error, timeout=45)

    def connection_error(self, error):
        self.finish(False, str(error))

    def finish(self, success, message):
        if self.finished:
            return
        self.finished = True
        self.failed = not success
        emit('done' if success else 'error', message=message)
        self.loop.quit()

def main():
    if len(sys.argv) != 2 or not re.fullmatch(r'/org/bluez/hci[0-9]+/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}', sys.argv[1]):
        emit('error', message='Invalid Bluetooth device')
        return 1
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()
    agent = PairingAgent(bus, sys.argv[1], loop)
    manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
    manager.RegisterAgent(AGENT_PATH, 'KeyboardDisplay')

    def read_input(source, condition):
        line = sys.stdin.readline()
        if not line:
            agent.cancel()
            return False
        try:
            message = json.loads(line)
            if not isinstance(message, dict):
                raise ValueError('Expected an object')
            agent.respond(message)
        except (ValueError, TypeError):
            emit('validation', message='Invalid pairing response')
        return True

    def deadline():
        agent.cancel()
        return False

    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, read_input)
    GLib.timeout_add_seconds(120, deadline)
    emit('status', message='Pairing…')
    agent.device.Pair(reply_handler=agent.paired, error_handler=agent.connection_error, timeout=90)
    try:
        loop.run()
    finally:
        try:
            manager.UnregisterAgent(AGENT_PATH)
        except dbus.DBusException:
            pass
    return int(agent.failed)

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (dbus.DBusException, OSError) as error:
        emit('error', message=str(error))
        sys.exit(1)
