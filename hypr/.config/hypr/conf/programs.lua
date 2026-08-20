-- Programs

local quickshell = "/home/luke/.config/quickshell/scripts/qs"

return {
	terminal = "uwsm app -- kitty",
	editor = "uwsm app -- kitty -e nvim",
	browser = "uwsm app -- gtk-launch helium.desktop",
	fileManager = "uwsm app -- kitty -e yazi",
	menu = quickshell .. " ipc call shell togglePicker launcher '{}'",
}
