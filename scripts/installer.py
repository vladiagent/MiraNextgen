import argparse
import configparser
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass


ROOT = Path(__file__).resolve().parents[1]
HOME = Path.home().resolve()
STATE = HOME / ".local/state/miraos-dots"
MANIFEST = STATE / "manifest.json"
ROOTS = (".config/", ".local/bin/", ".local/share/", ".local/lib/")
SOURCE_ROOTS = {
    "config": ".config",
    "scripts/bin": ".local/bin",
    "assets/share": ".local/share",
}
UNIT = "miraos-wallpaper-theme.path"
INTERFACE = "org.gnome.desktop.interface"
PREFERENCES = {"font-name": "'Google Sans 11'", "color-scheme": "'prefer-dark'"}


@dataclass(frozen=True)
class File:
    data: bytes
    mode: int = 0o644
    symlink: bool = False

    def identity(self):
        return {
            "sha256": hashlib.sha256(self.data).hexdigest(),
            "mode": self.mode,
            "symlink": self.symlink,
        }


def require(condition, message):
    if not condition:
        raise ValueError(message)


def prompt(message):
    if not sys.stdin.isatty():
        raise ValueError("This operation requires confirmation in a terminal.")
    return input(f"{message} [y/N] ").strip().lower() in {"y", "yes"}


def file_at(path):
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(mode):
        return File(os.fsencode(os.readlink(path)), 0, True)
    require(stat.S_ISREG(mode), f"Expected a file at {path}")
    return File(path.read_bytes(), stat.S_IMODE(mode))


def safe_path(base, relative):
    path = Path(relative)
    require(not path.is_absolute() and path.parts and ".." not in path.parts,
            "Invalid installer path")
    parent = base
    for part in path.parts[:-1]:
        parent /= part
        require(not parent.is_symlink(), f"Symbolic-link directory: {parent}")
        require(not parent.exists() or parent.is_dir(), f"Expected a directory at {parent}")
    return base / path


def destination(relative):
    require(relative.startswith(ROOTS), "Invalid destination in installation manifest")
    return safe_path(HOME, relative)


def make_parents(path, made):
    if path.is_dir():
        return
    make_parents(path.parent, made)
    path.mkdir()
    made.append(path)


def put(path, content):
    if content is None:
        path.unlink(missing_ok=True)
        return
    fd, name = tempfile.mkstemp(prefix=".miraos-", dir=path.parent)
    temp = Path(name)
    try:
        with os.fdopen(fd, "wb") as handle:
            if not content.symlink:
                handle.write(content.data)
                os.fchmod(handle.fileno(), content.mode)
                handle.flush()
                os.fsync(handle.fileno())
        if content.symlink:
            temp.unlink()
            temp.symlink_to(os.fsdecode(content.data))
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def remove_dirs(paths):
    for path in sorted(set(paths), key=lambda item: len(item.parts), reverse=True):
        try:
            path.rmdir()
        except OSError:
            continue


def load_manifest():
    manifest = file_at(MANIFEST)
    if manifest is None:
        return {"version": 1, "files": {}, "directories": [], "preferences": {}}
    require(not manifest.symlink, "Installation manifest must be a regular file.")
    result = json.loads(manifest.data)
    require(result.get("version") == 1, "Unsupported installation manifest.")
    result.setdefault("preferences", {})
    return result


def save_manifest(manifest):
    put(MANIFEST, File((json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode(), 0o600))


def gather():
    payload = {}
    for source, target in SOURCE_ROOTS.items():
        directory = ROOT / source
        require(directory.is_dir(), f"Missing payload directory {source}")
        for path in sorted(directory.rglob("*")):
            if "__pycache__" in path.parts or path.suffix in {".pyc", ".pyo"}:
                continue
            require(not path.is_symlink(), f"Unexpected source link: {path.relative_to(ROOT)}")
            if path.is_dir():
                continue
            relative = (Path(target) / path.relative_to(directory)).as_posix()
            payload[relative] = file_at(path)
    unit = f".config/systemd/user/{UNIT}"
    require(unit in payload, f"Missing {UNIT}")
    payload[f".config/systemd/user/default.target.wants/{UNIT}"] = File(
        os.fsencode(f"../{UNIT}"), 0, True)
    return payload


def read_packages(args):
    data = configparser.ConfigParser(allow_no_value=True)
    with (ROOT / "scripts/packages.conf").open() as handle:
        data.read_file(handle)
    groups = ("core", "qt5", "sddm", "wallpapers", "integrations")
    result = []
    for group in groups:
        if group == "core" or getattr(args, group):
            result.extend(key + ("=" + value if value is not None else "")
                          for key, value in data[group].items())
    return result


def missing_packages(packages):
    check = subprocess.run(["pacman", "-T", *packages], text=True, capture_output=True)
    require(check.returncode in (0, 127), check.stderr.strip() or "pacman dependency check failed.")
    return check.stdout.splitlines()


def install_packages(packages, missing):
    if not missing:
        print("Dependencies are present.")
        return
    names = list(dict.fromkeys(re.split(r"[<=>]", item, maxsplit=1)[0] for item in missing))
    require(prompt("Install the missing packages and run a full Arch upgrade?"), "Package installation declined.")
    subprocess.run(["sudo", "pacman", "-Syu", "--needed", *names], check=True)
    require(not missing_packages(packages), "A dependency still does not satisfy the required version.")


def backup_dir():
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return Path(tempfile.mkdtemp(prefix=f"{stamp}-", dir=STATE / "backups"))


def preference(key):
    return subprocess.check_output(
        ["dconf", "read", "/org/gnome/desktop/interface/" + key], text=True,
        stderr=subprocess.DEVNULL,
    ).strip() or None


def set_preference(key, value):
    path = "/org/gnome/desktop/interface/" + key
    if value is None:
        command = ["dconf", "reset", path]
    elif value == PREFERENCES[key]:
        command = ["gsettings", "set", INTERFACE, key, value]
    else:
        command = ["dconf", "write", path, value]
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        command = ["dbus-run-session", "--", *command]
    result = subprocess.run(command, text=True, capture_output=True,
                            env=dict(os.environ, GSETTINGS_BACKEND="dconf", GIO_USE_VFS="local"))
    require(result.returncode == 0 and preference(key) == value,
            f"Could not write desktop preference {key}.")


def preference_plan(manifest, install, restore=False):
    plan = []
    for key, value in PREFERENCES.items():
        record = manifest["preferences"].get(key)
        if not install and record is None:
            continue
        before = preference(key)
        if record and before != record["installed"]:
            continue
        after = value if install else None
        if not install and restore:
            after = record["original"]
        if before != after or not install:
            plan.append((key, before, after))
    return plan


def apply(plan, prefs, manifest, *, install):
    changed = []
    changed_preferences = []
    made = []
    backup = backup_dir() if install and any(before is not None for _, before, _ in plan) else None
    try:
        for relative, before, after in plan:
            path = destination(relative)
            require(file_at(path) == before, f"File changed during the operation: {path}")
            make_parents(path.parent, made)
            if install:
                previous = manifest["files"].get(relative)
                if before is not None:
                    saved = backup / relative
                    saved.parent.mkdir(parents=True, exist_ok=True)
                    put(saved, before)
                if previous:
                    original = previous["backup"]
                elif before is None:
                    original = None
                else:
                    original = {"path": str(saved.relative_to(STATE)), "identity": before.identity()}
                manifest["files"][relative] = {"installed": after.identity(), "backup": original}
            else:
                del manifest["files"][relative]
            changed.append((path, before))
            put(path, after)
        if install:
            print("Validating installed Hyprland configuration.")
            subprocess.run(["hyprland", "--verify-config", "-c", str(HOME / ".config/hypr/hyprland.lua")],
                           check=True)
        for key, before, after in prefs:
            require(preference(key) == before, f"Desktop preference changed during the operation: {key}")
            changed_preferences.append((key, before))
            set_preference(key, after)
            if install:
                manifest["preferences"].setdefault(key, {"installed": after, "original": before})
            else:
                del manifest["preferences"][key]
        manifest["directories"] = sorted(set(manifest["directories"]) |
                                         {str(path.relative_to(HOME)) for path in made})
        save_manifest(manifest)
    except BaseException:
        try:
            for key, before in reversed(changed_preferences):
                set_preference(key, before)
        finally:
            for path, before in reversed(changed):
                put(path, before)
            remove_dirs(made)
        raise
    if backup is not None:
        print(f"Backup: {backup}")


def summary(plan, manifest):
    conflicts = []
    additions = 0
    updates = 0
    for relative, before, _ in plan:
        record = manifest["files"].get(relative)
        if before is None:
            additions += 1
        elif record and record["installed"] == before.identity():
            updates += 1
        else:
            conflicts.append(relative)
    print(f"Files to add: {additions}. Managed files to update: {updates}.")
    if conflicts:
        print("Existing files to back up and replace:")
        for relative in conflicts:
            print(f"  ~/{relative}")


def notification_conflicts():
    active = []
    owner = subprocess.run(
        ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
         "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"],
        text=True, capture_output=True,
    ).stdout.split()
    if len(owner) == 2 and owner[0] == "u" and owner[1].isdigit():
        try:
            command = Path(f"/proc/{owner[1]}/cmdline").read_bytes().split(b"\0")
        except OSError:
            command = []
        if command and (Path(os.fsdecode(command[0])).name != "quickshell" or
                        os.fsencode(HOME / ".config/quickshell") not in command):
            active.append("existing org.freedesktop.Notifications owner")
    for unit in ("dunst.service", "mako.service", "swaync.service", "fnott.service"):
        status = subprocess.run(
            ["systemctl", "--user", "show", unit, "-p", "ActiveState", "-p", "UnitFileState"],
            text=True, capture_output=True,
        ).stdout.splitlines()
        if any(value in status for value in (
            "ActiveState=active", "ActiveState=activating",
            "UnitFileState=enabled", "UnitFileState=enabled-runtime",
        )):
            active.append(unit)
    return active


def reload_units(stop_path=False):
    if stop_path:
        subprocess.run(["systemctl", "--user", "stop", UNIT], capture_output=True)
    subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True)


def system_component(component, operation):
    if component == "SDDM":
        command = ["sudo", "bash", str(ROOT / "sddm/install.sh"), operation]
        command.append(pwd.getpwuid(os.getuid()).pw_name)
    else:
        command = ["sudo", "/usr/bin/python", "-I", str(ROOT / "boot/uki-splash.py"), operation]
    if prompt(f"{operation.capitalize()} system-wide {component} assets?"):
        subprocess.run(command, check=True)


def enable_state():
    safe_path(HOME, ".local/state/miraos-dots/manifest.json")
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(not STATE.is_symlink() and not (STATE / "backups").is_symlink(),
            "Installer state must use regular directories.")
    (STATE / "backups").mkdir(mode=0o700, exist_ok=True)
    for directory in (STATE, STATE / "backups"):
        require(directory.stat().st_uid == os.getuid() and not directory.stat().st_mode & 0o077,
                f"Installer state needs owner-only permissions at {directory}.")
    descriptor = os.open(STATE / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    return descriptor


def install(args):
    values = {}
    for line in Path("/etc/os-release").read_text().splitlines():
        if line.startswith(("ID=", "ID_LIKE=")):
            key, value = line.split("=", 1)
            values[key] = "".join(shlex.split(value))
    require(values.get("ID") == "arch" or
            (values.get("ID") == "miraos" and "arch" in values.get("ID_LIKE", "").split()),
            "MiraOS Dots requires Arch Linux.")
    packages = read_packages(args)
    missing = missing_packages(packages)
    print("Missing dependencies: " + ", ".join(missing) if missing else "Dependencies are present.")
    payload = gather()
    manifest = load_manifest()
    generated = set((ROOT / "scripts/generated-paths.txt").read_text().splitlines())

    def plan_for(files, current):
        plan = []
        for relative, after in sorted(files.items()):
            before = file_at(destination(relative))
            owned = current["files"].get(relative)
            if before and not before.symlink and relative in generated:
                if relative == ".config/waypaper/config.ini" or (
                    owned and before.identity() != owned["installed"]
                ):
                    continue
            if before != after:
                plan.append((relative, before, after))
        return plan

    plan = plan_for(payload, manifest)
    prefs = preference_plan(manifest, True) if shutil.which("dconf") else None
    summary(plan, manifest)
    if prefs is None or prefs:
        print("Desktop preferences include Google Sans 11 and the dark color scheme.")
    conflicts = notification_conflicts()
    if conflicts:
        print("Competing notification services: " + ", ".join(conflicts))
    if args.dry_run:
        if args.qt5:
            print("Would build the Qt 5 bridge from source.")
        if args.sddm or args.boot:
            print("System-wide assets would require separate confirmation.")
        print("Dry run complete.")
        return
    require(not conflicts, "Disable competing notification services before installing Quickshell.")
    if plan or prefs is None or prefs or args.qt5:
        require(prompt("Install these desktop files and preferences?"), "Installation declined.")
    install_packages(packages, missing)
    descriptor = enable_state()
    try:
        manifest = load_manifest()
        require(plan_for(payload, manifest) == plan,
                "The destination changed since review. Run the installer again.")
        current_prefs = preference_plan(manifest, True)
        require(prefs is None or current_prefs == prefs,
                "Desktop preferences changed since review. Run the installer again.")
        if args.qt5:
            relative = ".local/lib/vladi-theme/qt5/plugins/platformthemes/libvladi-kde-compat.so"
            with tempfile.TemporaryDirectory(prefix="miraos-qt5-") as tmp:
                output = Path(tmp) / "bridge.so"
                subprocess.run([sys.executable, "-B", str(ROOT / "scripts/build-qt5-bridge.py"), str(output)],
                               check=True)
                bridge_plan = plan_for({relative: file_at(output)}, manifest)
            if bridge_plan:
                summary(bridge_plan, manifest)
                require(prompt("Install the Qt 5 theme bridge?"), "Qt 5 installation declined.")
                plan += bridge_plan
        apply(plan, current_prefs, manifest, install=True)
    finally:
        os.close(descriptor)
    reload_units()
    for selected, component in ((args.sddm, "SDDM"), (args.boot, "boot branding")):
        if selected:
            system_component(component, "install")
    print("Desktop files are ready. Start a new Hyprland session when convenient.")


def uninstall(args):
    manifest = load_manifest()

    def plan_for(current):
        plan = []
        kept = []
        for relative, record in current["files"].items():
            before = file_at(destination(relative))
            if before is not None and before.identity() != record["installed"]:
                kept.append(relative)
                continue
            restored = None
            if args.restore and record["backup"]:
                backup = record["backup"]
                require(backup["path"].startswith("backups/"), f"Invalid backup for {relative}")
                restored = file_at(safe_path(STATE, backup["path"]))
                require(restored is not None and restored.identity() == backup["identity"],
                        f"Backup is missing or has changed for {relative}")
            plan.append((relative, before, restored))
        return plan, kept

    plan, kept = plan_for(manifest)
    prefs = preference_plan(manifest, False, args.restore)
    print(f"Owned files to remove or restore: {len(plan)}.")
    if prefs:
        print("Owned desktop preferences to remove or restore: " + ", ".join(key for key, _, _ in prefs))
    if kept:
        print("Modified files to keep:")
        for relative in kept:
            print(f"  ~/{relative}")
    if args.dry_run:
        return
    if plan or prefs:
        require(prompt("Uninstall these MiraOS Dots files and preferences?"), "Uninstallation declined.")
        descriptor = enable_state()
        try:
            manifest = load_manifest()
            require(plan_for(manifest) == (plan, kept),
                    "The installation changed since review. Run the uninstaller again.")
            require(preference_plan(manifest, False, args.restore) == prefs,
                    "Desktop preferences changed since review. Run the uninstaller again.")
            apply(plan, prefs, manifest, install=False)
            remove_dirs(safe_path(HOME, name + "/.miraos").parent
                        for name in manifest["directories"])
        finally:
            os.close(descriptor)
        reload_units(stop_path=any(
            relative == f".config/systemd/user/{UNIT}" and before is not None and after is None
            for relative, before, after in plan
        ))
    for selected, component in ((args.sddm, "SDDM"), (args.boot, "boot branding")):
        if selected:
            system_component(component, "uninstall")
    print(f"Installation records and backups: {STATE}")


def main():
    require(os.geteuid() != 0, "Run MiraOS Dots as your regular user.")
    safe_path(HOME, ".local/state/miraos-dots/manifest.json")
    for variable, default in (("XDG_CONFIG_HOME", ".config"), ("XDG_DATA_HOME", ".local/share")):
        value = os.environ.get(variable)
        require(not value or Path(value).resolve() == HOME / default,
                f"Use the default {variable} under your home directory.")
    parser = argparse.ArgumentParser(description="MiraOS Dots")
    subparsers = parser.add_subparsers(dest="operation", required=True)
    setup = subparsers.add_parser("install")
    remove = subparsers.add_parser("uninstall")
    for command in (setup, remove):
        command.add_argument("--dry-run", action="store_true", help="show the plan and exit")
        command.add_argument("--sddm", action="store_true", help="include the system-wide SDDM theme")
        command.add_argument("--boot", action="store_true", help="include supported boot branding")
    setup.add_argument("--qt5", action="store_true", help="build and install the Qt 5 theme bridge")
    setup.add_argument("--wallpapers", action="store_true", help="install the optional Arch wallpaper package")
    setup.add_argument("--integrations", action="store_true", help="install Firefox, Nautilus and Blueman")
    remove.add_argument("--restore", action="store_true", help="restore original files from the first backup")
    args = parser.parse_args()
    print("MiraOS Dots")
    (install if args.operation == "install" else uninstall)(args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"MiraOS Dots: {error}")
    except (EOFError, KeyboardInterrupt):
        sys.exit("\nMiraOS Dots: cancelled.")
