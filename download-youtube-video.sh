#!/bin/bash

# Trap Ctrl+C (SIGINT)
trap "echo -e '\nStopping...'; kill 0; exit 1" SIGINT

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Extractor args (ANDROID client)
YT_ARGS="youtube:player_client=android,-android_sdkless"

# -------------------------
# User input
# -------------------------
read -p "Enter YouTube URL (Video or Playlist): " url
read -p "Enter max video height (e.g., 360, 480, 720): " height

echo "Choose quality:"
echo "  1) Best quality"
echo "  2) Medium quality"
echo "  3) Low quality"
read -p "Enter choice [1-3]: " quality_choice

case "$quality_choice" in
  1)
    QUALITY_SORT="res:${height},fps,codec:h264,br"
    QUALITY_LABEL="best"
    ;;
  2)
    QUALITY_SORT="res:${height},codec:h264,br"
    QUALITY_LABEL="medium"
    ;;
  3)
    QUALITY_SORT="+res:${height},+size,+br"
    QUALITY_LABEL="low"
    ;;
  *)
    echo -e "${RED}Invalid choice. Exiting.${RESET}"
    exit 1
    ;;
esac

echo -e "${CYAN}Quality selected: ${QUALITY_LABEL}${RESET}"

# -------------------------
# Playlist detection
# -------------------------
echo -e "${CYAN}Detecting playlist name...${RESET}"

playlist_name=$(yt-dlp \
  --extractor-args "$YT_ARGS" \
  --flat-playlist \
  --print "%(playlist_title)s" \
  "$url" 2>/dev/null | head -n1)

if [ -n "$playlist_name" ]; then
  echo -e "${CYAN}Playlist detected: $playlist_name${RESET}"
  playlist_dir=$(echo "$playlist_name" | sed 's#[/:*?"<>|]#_#g')
  mkdir -p "$playlist_dir"
  cd "$playlist_dir" || exit 1
else
  echo -e "${CYAN}Single video detected.${RESET}"
fi

# -------------------------
# Setup
# -------------------------
archive_file=".downloaded.txt"
JOBS=4

video_ids=$(yt-dlp \
  --extractor-args "$YT_ARGS" \
  --flat-playlist \
  --print "%(id)s" \
  "$url" 2>/dev/null)

[ -z "$video_ids" ] && video_ids=$(yt-dlp \
  --extractor-args "$YT_ARGS" \
  --get-id \
  "$url")

mapfile -t video_array <<< "$video_ids"
total=${#video_array[@]}

echo -e "${CYAN}Found $total videos${RESET}"

# Semaphore
mkfifo pipe
exec 3<>pipe
rm pipe
for ((i=0;i<JOBS;i++)); do echo >&3; done

# -------------------------
# Download loop
# -------------------------
for idx in "${!video_array[@]}"; do
  read -u3
  {
    video_id="${video_array[$idx]}"
    current=$((idx + 1))
    full_url="https://www.youtube.com/watch?v=$video_id"

    echo -e "\n${CYAN}[${current}/${total}] Downloading: $full_url${RESET}"

    if ! yt-dlp \
        --extractor-args "$YT_ARGS" \
        --continue \
        --download-archive "$archive_file" \
        --merge-output-format mp4 \
        -S "$QUALITY_SORT" \
        -o "%(upload_date)s %(title)s.%(ext)s" \
        "$full_url"
    then
      echo -e "${RED}Failed: $video_id${RESET}"
    else
      echo -e "${GREEN}Done: $video_id${RESET}"
    fi

    echo >&3
  } &
done

wait
echo -e "\n${GREEN}All downloads completed!${RESET}"
