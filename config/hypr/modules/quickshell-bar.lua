hl.layer_rule({
    name = "quickshell-floating-bar-blur",
    match = { namespace = "^quickshell-floating-bar$" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.01,
    no_anim = true,
})

hl.on("hyprland.start", function()
    hl.exec_cmd('"' .. os.getenv("HOME") .. '/.local/bin/quickshell-bar"')
end)
