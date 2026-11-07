local toggle = '"' .. os.getenv("HOME") .. '/.local/bin/quickshell-bar" ipc call clipboard toggle'
hl.bind("SUPER + V", hl.dsp.exec_cmd(toggle), {
    description = "Toggle MiraOS clipboard history",
})
hl.layer_rule({
    name = "vladi-clipboard-native-animation",
    match = { namespace = "^vladi-clipboard$" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0.01,
})
