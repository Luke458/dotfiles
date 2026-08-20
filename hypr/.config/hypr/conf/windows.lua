-- Windows and workspaces

local floating_tools = {
    "^(blueman-manager)$",
    "^(com.github.wwmm.easyeffects)$",
    "^(nm-connection-editor)$",
    "^(org.pulseaudio.pavucontrol|pavucontrol)$",
}

hl.window_rule({
    name = "kitty-no-blur",
    match = { class = "^(kitty|scratch-terminal|scratch-files|scratch-monitor)$" },
    no_blur = true,
})

hl.window_rule({
    -- Ignore maximize requests from apps.
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland.
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- Scratchpad windows are spawned onto special workspaces, but these rules keep
-- their shape stable if they are restored or moved manually.
hl.window_rule({
    name = "scratch-terminal-layout",
    match = { class = "^scratch-terminal$" },
    float = true,
    center = true,
    size = "70% 70%",
})

hl.window_rule({
    name = "scratch-files-layout",
    match = { class = "^scratch-files$" },
    float = true,
    center = true,
    size = "75% 75%",
})

hl.window_rule({
    name = "scratch-monitor-layout",
    match = { class = "^scratch-monitor$" },
    float = true,
    center = true,
    size = "80% 80%",
})

-- Keep video PiP windows visible without letting them steal tiling space.
hl.window_rule({
    name = "pip-floating-pinned",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin = true,
    size = "30% 30%",
    move = "100%-w-24 100%-h-72",
})

-- Common utility dialogs are easier to use as centered transient windows.
hl.window_rule({
    name = "common-dialogs-float",
    match = { title = "^(Open|Save|Save As|Select|Choose|File Upload|Confirm).*" },
    float = true,
    center = true,
    size = "70% 70%",
})

hl.window_rule({
    name = "auth-dialogs-float",
    match = { title = "^(Authentication Required|Authenticate|Password Required)$" },
    float = true,
    center = true,
})

for _, class in ipairs(floating_tools) do
    hl.window_rule({
        name = "float-tool-" .. class:gsub("[^%w]+", "-"):gsub("^-", ""):gsub("-$", ""),
        match = { class = class },
        float = true,
        center = true,
        size = "70% 70%",
    })
end
