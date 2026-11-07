local toggle = '"' .. os.getenv("HOME") .. '/.local/bin/quickshell-bar" ipc call emoji toggle'
hl.bind("SUPER + period", hl.dsp.exec_cmd(toggle), {
    description = "Toggle MiraOS emoji picker",
})
hl.layer_rule({
    name = "miraos-emoji-picker",
    match = { namespace = "^miraos-emoji$" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0.01,
})
