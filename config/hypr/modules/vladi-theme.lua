hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "")
local plugins = os.getenv("HOME") .. "/.local/lib/vladi-theme"
hl.env("QT_PLUGIN_PATH", plugins .. "/qt6/plugins:" .. plugins .. "/qt5/plugins")
