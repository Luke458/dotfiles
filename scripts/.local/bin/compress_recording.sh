#!/usr/bin/env bash

# Inputs and Outputs
LEFT_INPUT="$HOME/Videos/left_screen.mp4"
RIGHT_INPUT="$HOME/Videos/right_screen.mp4"
OUTPUT_FILE="$HOME/Videos/discord_ready.mp4"

# 1. Get the video duration in seconds using ffprobe
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$LEFT_INPUT")

# Discord limit safety buffer (24.5 MB in Kilobits)
TARGET_SIZE_KB=$((245 * 1024 * 8 / 10)) 

# 2. Calculate the maximum total bitrate allowed based on duration
TOTAL_BITRATE=$(echo "$TARGET_SIZE_KB / $DURATION" | bc)

# Allocate 128 kbps to audio, the rest goes to video
AUDIO_BITRATE=128
VIDEO_BITRATE=$((TOTAL_BITRATE - AUDIO_BITRATE))

# --- THE QUALITY FIX FOR SHORT CLIPS ---
# If the calculated bitrate is insanely high (short video), we cap it at 12,000 kbps.
# 12 Mbps for a 1080p-height AV1 stream looks absolutely pristine.
if [ "$VIDEO_BITRATE" -gt 12000 ]; then
    echo "Short clip detected! Capping video bitrate at 12000k for maximum fidelity."
    VIDEO_BITRATE=12000
fi

# Safety check for ultra-long videos
if [ "$VIDEO_BITRATE" -lt 200 ]; then
    echo "Warning: Video is too long to compress under 25MB with good quality!"
    VIDEO_BITRATE=200
fi

echo "Recording Duration: $DURATION seconds"
echo "Target Encoding Bitrate: ${VIDEO_BITRATE}k"

# 3. Pass 1: Analyze filter network using a slower, higher-quality compression structure (Preset 4)
ffmpeg -y -i "$LEFT_INPUT" -i "$RIGHT_INPUT" \
  -filter_complex "[0:v]setpts=N/FRAME_RATE/TB[l]; [1:v]setpts=N/FRAME_RATE/TB[r]; [l][r]hstack,scale=-1:1080" \
  -c:v libsvtav1 -b:v "${VIDEO_BITRATE}k" -preset 4 \
  -pass 1 -f null /dev/null

# 4. Pass 2: Render final file
ffmpeg -y -i "$LEFT_INPUT" -i "$RIGHT_INPUT" \
  -filter_complex "[0:v]setpts=N/FRAME_RATE/TB[l]; [1:v]setpts=N/FRAME_RATE/TB[r]; [l][r]hstack,scale=-1:1080" \
  -c:v libsvtav1 -b:v "${VIDEO_BITRATE}k" -preset 4 \
  -pass 2 \
  -c:a libopus -b:a "${AUDIO_BITRATE}k" \
  "$OUTPUT_FILE"

# Clean up FFmpeg log files
rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree SvtAv1WithLog.log

echo "Done! Optimized high-fidelity file saved to: $OUTPUT_FILE"
