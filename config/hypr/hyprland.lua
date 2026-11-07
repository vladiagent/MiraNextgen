require('modules.monitors')
require('modules.binds')
require('modules.autostart')
require('modules.env')
require('modules.decorations')
require('modules.misc')
require('modules.input')
require('modules.windowrules')
require("modules.quickshell-bar")

local config = os.getenv("HOME") .. "/.config"
local overrides = config .. "/hypr/modules/local-overrides.lua"
local localFile = io.open(overrides, "r")
if localFile then
    localFile:close()
    dofile(overrides)
end

dofile(config .. "/matugen/miraos/generated/hyprland.lua")
require("modules.vladi-theme")

require("modules.quickshell-clipboard")
require("modules.quickshell-emoji")
