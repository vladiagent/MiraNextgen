local accent = "{{role.accent}}"
local inactive = "{{role.surface_hover}}"
hl.config({ general = { col = {
    active_border = { colors = { "rgba(" .. accent:sub(2) .. "ff)" } },
    inactive_border = "rgba(" .. inactive:sub(2) .. "ff)",
} } })
