local accent = "#ffb3af"
local inactive = "#504945"
hl.config({ general = { col = {
    active_border = { colors = { "rgba(" .. accent:sub(2) .. "ff)" } },
    inactive_border = "rgba(" .. inactive:sub(2) .. "ff)",
} } })
