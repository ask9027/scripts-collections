#!/bin/bash

# Define color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

read -p "Enter YouTube URL (Video or Playlist): " url
read -p "Enter preferred video height (e.g., 360, 480, 720): " height

mkdir -p tmp
cd tmp || exit 1

# Get video IDs (handles both single and playlist)
video_ids=$(yt-dlp --flat-playlist --print "%(id)s" "$url" -4 2>/dev/null)
[ -z "$video_ids" ] && video_ids=$(yt-dlp --get-id "$url" -4)

# Count total videos
total=$(echo "$video_ids" | wc -w)
count=1

for video_id in $video_ids; do
  full_url="https://www.youtube.com/watch?v=$video_id"
  echo -e "\n${CYAN}[${count}/${total}] Processing: $full_url${RESET}"

  # Fetch metadata
  info_json=$(yt-dlp -J "$full_url" -4 2>/dev/null)
  if [ -z "$info_json" ]; then
    echo -e "${RED}Failed to fetch info for $video_id${RESET}"
    ((count++))
    continue
  fi

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
	  (.protocol != "m3u8" and .protocol != "m3u8_native") and
	  (.format_id | test("(?i)drc") | not)
    ) |
    {id: .format_id, tbr: .tbr} |
    @base64' | \
    while read -r line; do
      echo "$line" | base64 -d | jq -r '[.id, .tbr] | @tsv'
    done | sort -nk2 | head -n1 | cut -f1)

  echo -e "${YELLOW}Selected video format: $video_format${RESET}"
  echo -e "${YELLOW}Selected audio format: $audio_format${RESET}"

  if [ -z "$video_format" ] || [ -z "$audio_format" ]; then
    echo -e "${RED}Skipping $video_id due to format detection failure.${RESET}"
    ((count++))
    continue
  fi

  # Download and merge
  yt-dlp -f "${video_format}+${audio_format}" -o "%(upload_date)s %(title)s.%(ext)s" "$full_url" -4 || {
    echo -e "${RED}Title-based filename failed. Trying with video ID...${RESET}"
    yt-dlp -f "${video_format}+${audio_format}" -o "%(upload_date)s %(title).85s.%(ext)s" "$full_url" -4
  }

  echo -e "${GREEN}Downloaded video ${count}/${total}${RESET}"
  ((count++))
done

echo -e "\n${GREEN}All done!${RESET}"
