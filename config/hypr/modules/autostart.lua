hl.on("hyprland.start", function ()
  hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
  local restore = '/usr/bin/python -B "' .. os.getenv("HOME") .. '/.config/quickshell-wallpapers/backend.py" restore'
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP; "
    .. "systemctl --user start miraos-wallpaper-theme.path; " .. restore)
end)
