#!/bin/bash

# Define color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

read -p "Enter YouTube URL (Video or Playlist): " url
read -p "Enter preferred video height (e.g., 360, 480, 720): " height

# ➕ NEW: get playlist title (fallback for single video)
echo -e "${CYAN}Detecting playlist name...${RESET}"

playlist_name=$(yt-dlp \
  --flat-playlist \
  --print "%(playlist_title)s" \
  "$url" -4 2>/dev/null | head -n1)

[ -z "$playlist_name" ] && playlist_name="single_video"

# ➕ NEW: sanitize folder name
playlist_dir=$(echo "$playlist_name" | sed 's#[/:*?"<>|]#_#g')

mkdir -p "$playlist_dir"
cd "$playlist_dir" || exit 1

# ➕ NEW: per-playlist archive + ID map
archive_file=".downloaded.txt"
id_map_file="video_id_map.txt"

# Get video IDs (handles both single and playlist)
video_ids=$(yt-dlp --flat-playlist --print "%(id)s" "$url" -4 2>/dev/null)
[ -z "$video_ids" ] && video_ids=$(yt-dlp --get-id "$url" -4)
echo $video_ids > video_ids.txt
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
  video_format=$(
  jq -r --argjson h "$height" '
    def valid:
      select(
        .vcodec != "none" and
        .acodec == "none" and
        (.ext == "mp4" or .ext == "webm") and
        (.height != null) and
        (.height <= $h)
      );

    # 1️⃣ exact height → lowest bitrate
    [ .[] | valid | select(.height == $h) ] as $exact
    |
    if ($exact | length) > 0 then
      $exact
      | sort_by(.tbr // 0)
      | .[0]
    else
      # 2️⃣ fallback height → highest height ≤ h
      [ .[] | valid ]
      | group_by(.height)
      | sort_by(.[0].height)
      | last
      | sort_by(.tbr // 0)
      | .[0]
    end
    |
    .format_id
  ' <<<"$formats"
  )

  # Select best audio-only format
  audio_format=$(
  echo "$formats" | jq -r '
    def valid:
      select(
        .vcodec == "none" and
        .acodec != "none" and
        (.ext == "m4a" or .ext == "webm") and
        (.protocol != "m3u8" and .protocol != "m3u8_native") and
        (.format_note // "" | test("medium")) and
        (.format_note // "" | test("drc") | not)
      );

    # 1️⃣ default + medium
    [ .[] | valid | select(.format_note // "" | test("default")) ] as $default
    |
    if ($default | length) > 0 then
      $default
    else
      # 2️⃣ any medium
      [ .[] | valid ]
    end
    |
    .[]
    | [.format_id, (.tbr // 0)]
    | @tsv
  ' | sort -nk2 | head -n1 | cut -f1
  )

  echo -e "${YELLOW}Selected video format: $video_format${RESET}"
  echo -e "${YELLOW}Selected audio format: $audio_format${RESET}"

  if [ -z "$video_format" ] || [ -z "$audio_format" ]; then
    echo -e "${RED}Skipping $video_id due to format detection failure.${RESET}"
    ((count++))
    continue
  fi

  # Download and merge
# ➕ NEW: get final filename before download
final_file=$(yt-dlp \
  --get-filename \
  -f "${video_format}+${audio_format}" \
  -o "%(upload_date)s %(title)s.%(ext)s" \
  "$full_url" -4)

yt-dlp \
  --continue \
  --download-archive "$archive_file" \
  -f "${video_format}+${audio_format}" \
  -o "%(upload_date)s %(title)s.%(ext)s" \
  "$full_url" -4 && {

  # ➕ NEW: save video_id → filename mapping (no duplicates)
  if ! grep -q "^$video_id |" "$id_map_file" 2>/dev/null; then
    echo "$video_id | $final_file" >> "$id_map_file"
  fi
} || {
    echo -e "${RED}Title-based filename failed. Trying with video ID...${RESET}"
    yt-dlp \
  --continue \
  --download-archive "$archive_file" \
  -f "${video_format}+${audio_format}" \
  -o "%(upload_date)s %(title).85s.%(ext)s" \
  "$full_url" -4
  }

  echo -e "${GREEN}Downloaded video ${count}/${total}${RESET}"
  ((count++))
done

echo -e "\n${GREEN}All done!${RESET}"
