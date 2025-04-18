#!/bin/bash

URL="$1"

if [ -z "$URL" ]; then
  echo "Usage: $0 <YouTube URL or Playlist>"
  exit 1
fi

mkdir -p tmp
cd tmp || exit 1

# Get list of video IDs in the playlist
video_ids=$(yt-dlp --flat-playlist --print "%(id)s" "$URL")

# If not a playlist, just use the single video
if [ -z "$video_ids" ]; then
  video_ids=$(yt-dlp --get-id "$URL")
fi

for video_id in $video_ids; do
  echo -e "\nProcessing https://www.youtube.com/watch?v=$video_id"

  # Get only formats in JSON
  yt-dlp -J "https://www.youtube.com/watch?v=$video_id" > "info_$video_id.json"

  # Extract title
  title=$(jq -r '.title' "info_$video_id.json" | sed 's#[\\/:"*?<>|]##g')

  # Extract formats
  formats=$(jq '.formats' "info_$video_id.json")

  # Get lowest TBR 480p video
  video_format=$(echo "$formats" | jq -r '.[] | select(.height == 480 and .vcodec != "none") | {id: .format_id, tbr: .tbr} | @base64' | \
    while read -r line; do
      echo "$line" | base64 -d | jq -r '[.id, .tbr] | @tsv'
    done | sort -nk2 | head -n1 | cut -f1)

  # Get lowest TBR audio (prefer m4a or webm, avoid m3u8_dash)
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
  echo "Selected Video: $video_format, Audio: $audio_format"

  # Download and merge
  yt-dlp -f "${video_format}+${audio_format}" -o "${title}.%(ext)s" "https://www.youtube.com/watch?v=$video_id"
done

echo -e "\nDone!"
