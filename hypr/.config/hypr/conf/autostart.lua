-- Autostart

local quickshell = "/home/luke/.config/quickshell/scripts/launch-shell"

local commands = {
	"uwsm app -- easyeffects --hide-window --service-mode",
	"uwsm app -s b -t service -a luke-quickshell -d 'Luke Quickshell' -- " .. quickshell,
	"uwsm app -- hypridle",
}

hl.on("hyprland.start", function()
	for _, command in ipairs(commands) do
		hl.exec_cmd(command)
	end
end)
