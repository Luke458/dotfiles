-- Quickshell integration

local programs = require("conf.programs")
local mainMod = "SUPER"
local quickshell = "/home/luke/.config/quickshell/scripts/qs"

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(programs.menu))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(quickshell .. " ipc call shell togglePicker pass '{}'"))
hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd(quickshell .. " ipc call shell togglePicker power '{}'"))
hl.bind(mainMod .. " + SHIFT + BackSpace", hl.dsp.exec_cmd(quickshell .. " ipc call lock lock"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("/home/luke/.config/quickshell/scripts/restart-shell"))

hl.layer_rule({
    name = "qs-picker-private",
    match = { namespace = "^qs-picker$" },
    no_screen_share = true,
})

hl.layer_rule({
    name = "qs-bar-blur",
    match = { namespace = "^qs-bar$" },
    blur = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name = "qs-popup-blur",
    match = { namespace = "^qs-popup$" },
    blur = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name = "qs-tray-menu-blur",
    match = { namespace = "^qs-tray-menu$" },
    blur = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name = "qs-notifications-private",
    match = { namespace = "^qs-notifications$" },
    no_screen_share = true,
})
