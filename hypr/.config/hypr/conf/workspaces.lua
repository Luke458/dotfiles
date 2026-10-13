-- Workspaces

-- Keep gaps even when a workspace has a single tiled window. Only fullscreen
-- windows go gap-less (Hyprland already does this; the rule keeps borders and
-- rounding consistent with it).
hl.workspace_rule({
	workspace = "f[1]",
	gaps_out = 0,
	gaps_in = 0,
})

hl.window_rule({
	name = "smart-gaps-fullscreen",
	match = {
		float = false,
		workspace = "f[1]",
	},
	border_size = 0,
	rounding = 0,
})
