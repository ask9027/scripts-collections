#!/bin/bash

read -p "Enter YouTube URL (Video or Playlist): " url
read -p "Enter preferred video height (e.g., 360, 480, 720): " height

mkdir -p tmp
cd tmp || exit 1

# Get video IDs (handles both single and playlist)
video_ids=$(yt-dlp --flat-playlist --print "%(id)s" "$url" 2>/dev/null)
[ -z "$video_ids" ] && video_ids=$(yt-dlp --get-id "$url")

for video_id in $video_ids; do
  full_url="https://www.youtube.com/watch?v=$video_id"
  echo -e "\nProcessing: $full_url"

  # Fetch metadata
  info_json=$(yt-dlp -J "$full_url" 2>/dev/null)
  [ -z "$info_json" ] && echo "Failed to fetch info for $video_id" && continue

  formats=$(echo "$info_json" | jq '.formats')

  # Select best video format for given height
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

  # Select best audio-only format
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

  if [ -z "$video_format" ] || [ -z "$audio_format" ]; then
    echo "Skipping $video_id due to format detection failure."
    continue
  fi

  # Download and merge
  yt-dlp -f "${video_format}+${audio_format}" -o "%(title)s.%(ext)s" "$full_url" || {
    echo "Title-based filename failed. Trying with video ID..."
    yt-dlp -f "${video_format}+${audio_format}" -o "%(id)s.%(ext)s" "$full_url"
  }
done

echo -e "\nAll done!"

