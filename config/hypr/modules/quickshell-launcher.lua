local toggle = '"' .. os.getenv("HOME") .. '/.local/bin/quickshell-bar" ipc call launcher toggle'
hl.bind("Super_L", hl.dsp.exec_cmd(toggle), {
    release = true,
    description = "Toggle MiraOS launcher and workspace overview",
})

hl.layer_rule({
    name = "vladi-launcher-native-animations",
    match = { namespace = "^(vladi-launcher|vladi-volume)$" },
    no_anim = true,
})
