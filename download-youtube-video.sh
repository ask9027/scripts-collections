#!/bin/bash

read -p "Enter YouTube URL: " url
read -p "Enter preferred video height (e.g., 360, 480, 720): " height

# Get format data as JSON
formats=$(yt-dlp -J "$url" | jq '.formats')

# Get best video-only format with specified height and lowest TBR
video_format=$(echo "$formats" | jq -r --argjson h "$height" '
  .[] |
  select(
    .vcodec != "none" and .acodec == "none" and
    .height == $h and
    (.ext == "mp4" or .ext == "webm")
  ) |
  {id: .format_id, tbr: .tbr} |
  @base64' | \
  while read -r line; do
    echo "$line" | base64 -d | jq -r '[.id, .tbr] | @tsv'
  done | sort -nk2 | head -n1 | cut -f1)

# Get best audio-only format (avoid m3u8)
audio_format=$(echo "$formats" | jq -r '
  .[] |
  select(
    .vcodec == "none" and .acodec != "none" and
    (.ext == "m4a" or .ext == "webm") and
    (.protocol != "m3u8" and .protocol != "m3u8_native")
  ) |
  {id: .format_id, tbr: .tbr} |
  @base64' | \
  while read -r line; do
    echo "$line" | base64 -d | jq -r '[.id, .tbr] | @tsv'
  done | sort -nk2 | head -n1 | cut -f1)

echo "Selected video format: $video_format"
echo "Selected audio format: $audio_format"

# Download and merge
yt-dlp -f "$video_format+$audio_format" "$url" -o "%(title)s.%(ext)s"
