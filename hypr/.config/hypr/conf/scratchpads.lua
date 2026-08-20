-- Special scratchpads

local mainMod = "SUPER"

local scratchpads = {
    {
        name = "term",
        key = "code:49",
        move_key = "SHIFT + code:49",
        command = "kitty --class scratch-terminal --title scratch-terminal",
        rules = {
            workspace = "special:term",
            float = true,
            center = true,
            size = { "monitor_w*0.7", "monitor_h*0.7" },
        },
    },
    {
        name = "files",
        key = "SHIFT + E",
        move_key = "CTRL + SHIFT + E",
        command = "kitty --class scratch-files --title scratch-files -e yazi",
        rules = {
            workspace = "special:files",
            float = true,
            center = true,
            size = { "monitor_w*0.75", "monitor_h*0.75" },
        },
    },
    {
        name = "monitor",
        key = "B",
        move_key = "SHIFT + B",
        command = "kitty --class scratch-monitor --title scratch-monitor -e btop",
        rules = {
            workspace = "special:monitor",
            float = true,
            center = true,
            size = { "monitor_w*0.8", "monitor_h*0.8" },
        },
    },
}

local function special_workspace_name(name)
    return "special:" .. name
end

local function workspace_has_windows(name)
    local workspace = hl.get_workspace(special_workspace_name(name))
    return workspace ~= nil and (workspace.windows or 0) > 0
end

local function spawn_scratchpad(spec)
    hl.exec_cmd(spec.command, spec.rules)
end

local function toggle_scratchpad(spec)
    if not workspace_has_windows(spec.name) then
        hl.dispatch(hl.dsp.workspace.toggle_special(spec.name))
        spawn_scratchpad(spec)
        return
    end

    hl.dispatch(hl.dsp.workspace.toggle_special(spec.name))
end

for _, spec in ipairs(scratchpads) do
    hl.bind(mainMod .. " + " .. spec.key, function()
        toggle_scratchpad(spec)
    end)

    hl.bind(mainMod .. " + " .. spec.move_key, hl.dsp.window.move({
        workspace = special_workspace_name(spec.name),
    }))
end
