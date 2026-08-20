-- MPV clipping script
--
-- Creates video clips from the currently playing file.
-- Requires ffmpeg to be installed and in the system's PATH.
--
-- Key Bindings:
-- Ctrl+Shift+S : Set clip start time.
-- Ctrl+Shift+E : Set clip end time.
-- Ctrl+Shift+X : Save the clip.
-- Ctrl+Shift+C : Cancel the clip selection.

local mp = require 'mp'

local start_time = nil
local end_time = nil

-- Function to format seconds into HH:MM:SS.ms
local function format_time(time_in_seconds)
    if time_in_seconds < 0 then time_in_seconds = 0 end
    local hours = math.floor(time_in_seconds / 3600)
    local mins = math.floor((time_in_seconds % 3600) / 60)
    local secs = time_in_seconds % 60
    return string.format("%02d:%02d:%06.3f", hours, mins, secs)
end

function set_start_time()
    start_time = mp.get_property_native("time-pos")
    if start_time == nil then
        mp.osd_message("Could not get current time.")
        return
    end
    -- If end time is set and is before the new start time, clear it
    if end_time and end_time < start_time then
        end_time = nil
    end
    local friendly_time = format_time(start_time)
    mp.osd_message(string.format("Clip start set: %s", friendly_time))
end

function set_end_time()
    if not start_time then
        mp.osd_message("Set a start time first (Ctrl+Shift+S).")
        return
    end
    end_time = mp.get_property_native("time-pos")
    if end_time == nil then
        mp.osd_message("Could not get current time.")
        return
    end
    if end_time <= start_time then
        mp.osd_message("End time must be after start time.")
        end_time = nil
        return
    end
    local friendly_time = format_time(end_time)
    mp.osd_message(string.format("Clip end set: %s", friendly_time))
end

function save_clip()
    if not start_time or not end_time then
        mp.osd_message("Set both start and end times first.")
        return
    end

    local input_path = mp.get_property_native("path")
    if not input_path then
        mp.osd_message("Could not get input file path.")
        return
    end

    -- Generate a clean output filename
    local basename = input_path:match("(.*/)(.*)") or ""
    local filename = input_path:match(".*/(.*)%.[^.]+") or "clip"
    local extension = input_path:match("%.([^.]+)$") or "mkv"
    local start_secs_int = math.floor(start_time)
    local output_filename = string.format("%s-clip-%d.%s", filename, start_secs_int, extension)
    local output_path = basename .. output_filename

    local duration = end_time - start_time

    mp.osd_message(string.format("Clipping... saving to %s", output_filename))

    -- Use ffmpeg to create the clip. '-c copy' is fast and preserves quality.
    local args = {
        "ffmpeg",
        "-i", input_path,
        "-ss", tostring(start_time),
        "-t", tostring(duration),
        "-c", "copy",
        output_path
    }

    -- Run the command
    local res = mp.command_native({
        name = "run",
        args = args,
        capture_stdout = true,
        capture_stderr = true
    })

    if res.status == 0 then
        mp.osd_message(string.format("Clip saved: %s", output_filename), 5)
    else
        mp.osd_message(string.format("Error creating clip. Check console for details."), 5)
        print("ffmpeg stdout:\n" .. res.stdout)
        print("ffmpeg stderr:\n" .. res.stderr)
    end

    -- Reset for the next clip
    start_time = nil
    end_time = nil
end

function cancel_selection()
    start_time = nil
    end_time = nil
    mp.osd_message("Clip selection cancelled.")
end

mp.add_key_binding("Ctrl+Shift+S", "set_start", set_start_time)
mp.add_key_binding("Ctrl+Shift+E", "set_end", set_end_time)
mp.add_key_binding("Ctrl+Shift+X", "save_clip", save_clip)
mp.add_key_binding("Ctrl+Shift+C", "cancel_clip", cancel_selection)
