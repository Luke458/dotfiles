-- Monitors

local M = {}

M.left = {
    output = "DP-2",
    mode = "2560x1440@120",
    position = "0x0",
    scale = 1,
    enabled = true,
}

M.right = {
    output = "DP-1",
    mode = "2560x1440@120",
    position = "2560x0",
    scale = 1,
    enabled = true,
}

local function apply(spec)
    hl.monitor({
        output = spec.output,
        mode = spec.mode,
        position = spec.position,
        scale = spec.scale,
        disabled = false,
    })
end

function M.enable(spec)
    apply(spec)
    spec.enabled = true
end

function M.disable(spec)
    hl.monitor({
        output = spec.output,
        disabled = true,
    })
    spec.enabled = false
end

function M.is_active(spec)
    return spec.enabled
end

function M.toggle(spec)
    if M.is_active(spec) then
        M.disable(spec)
    else
        M.enable(spec)
    end
end

apply(M.left)
apply(M.right)

return M
