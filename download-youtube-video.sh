#!/bin/bash

# Trap Ctrl+C (SIGINT) to kill all background jobs and exit cleanly
trap "echo -e '\nStopping...'; kill 0; exit 1" SIGINT

# Color definitions for terminal output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Ask user for URL and preferred video height
read -p "Enter YouTube URL (Video or Playlist): " url
read -p "Enter preferred video height (e.g., 360, 480, 720): " height

echo -e "${CYAN}Detecting playlist name...${RESET}"

# Detect playlist title
playlist_name=$(yt-dlp --flat-playlist --print "%(playlist_title)s" "$url" -4 2>/dev/null | head -n1)

if [ -n "$playlist_name" ]; then
    echo -e "${CYAN}Playlist detected: $playlist_name${RESET}"

    # Replace invalid characters and create folder
    playlist_dir=$(echo "$playlist_name" | sed 's#[/:*?"<>|]#_#g')
    mkdir -p "$playlist_dir"
    cd "$playlist_dir" || exit 1
else
    echo -e "${CYAN}Single video detected. Using current directory.${RESET}"
fi

# Archive file prevents re-downloading already completed videos
archive_file=".downloaded.txt"

# Map file for linking video IDs to final file output
id_map_file="video_id_map.txt"

# Collect all video IDs from playlist or single video
video_ids=$(yt-dlp --flat-playlist --print "%(id)s" "$url" -4 2>/dev/null)

# Fallback method for single videos
[ -z "$video_ids" ] && video_ids=$(yt-dlp --get-id "$url" -4)

# Convert list into bash array
mapfile -t video_array <<< "$video_ids"
total=${#video_array[@]}

echo -e "${CYAN}Found $total videos${RESET}"

# Configure parallel jobs
JOBS=4
mkfifo pipe
exec 3<>pipe
rm pipe

# Fill job tokens (for semaphore behavior)
for ((i=0;i<JOBS;i++)); do echo >&3; done

# Loop through each video by index
for idx in "${!video_array[@]}"; do
  read -u3  # Acquire token (blocks if no jobs available)
  {
    video_id="${video_array[$idx]}"
    current=$((idx + 1))
    full_url="https://www.youtube.com/watch?v=$video_id"

    echo -e "\n${CYAN}[${current}/${total}] Processing: $full_url${RESET}"

    # Fetch metadata JSON for the video
    info_json=$(yt-dlp -J "$full_url" -4 2>/dev/null)
    if [ -z "$info_json" ]; then
      echo -e "\n${RED}Failed to fetch info for $video_id${RESET}" >&2
      echo >&3
      exit
    fi

    # Extract formats array via jq
    formats=$(echo "$info_json" | jq '.formats')

    # Select best matching video-only format <= requested height
    video_format=$(
      jq -r --argjson h "$height" '
        def valid:
          select(
            .vcodec != "none" and      # must have video
            .acodec == "none" and      # no audio stream
            (.ext == "mp4" or .ext == "webm") and
            (.height != null) and
            (.height <= $h)            # <= requested resolution
          );
        [ .[] | valid | select(.height == $h) ] as $exact
        |
        if ($exact | length) > 0 then
          # Prefer exact height
          $exact | sort_by(.tbr // 0) | .[0]
        else
          # Else pick highest under limit
          [ .[] | valid ]
          | group_by(.height)
          | sort_by(.[0].height)
          | last                       # highest resolution bucket
          | sort_by(.tbr // 0)
          | .[0]
        end
        |
        .format_id
      ' <<<"$formats"
    )

    # Select best clean audio format filtering out DRC & HLS
    audio_format=$(
      echo "$formats" | jq -r '
        def valid:
          select(
            .vcodec == "none" and              # no video
            .acodec != "none" and              # has audio
            (.ext == "m4a" or .ext == "webm") and
            (.protocol != "m3u8" and .protocol != "m3u8_native") and
            (.format_note // "" | test("medium")) and
            (.format_note // "" | test("drc") | not)
          );
        [ .[] | valid | select(.format_note // "" | test("default")) ] as $default
        |
        if ($default | length) > 0 then
          $default
        else
          [ .[] | valid ]
        end
        |
        .[]
        | [.format_id, (.tbr // 0)]
        | @tsv
      ' | sort -nk2 | head -n1 | cut -f1
    )

    # Log chosen formats
    >&2 echo -e "\n${YELLOW}Selected video: $video_format${RESET}"
    >&2 echo -e "${YELLOW}Selected audio: $audio_format${RESET}"

    # Skip if format missing
    if [ -z "$video_format" ] || [ -z "$audio_format" ]; then
      echo -e "\n${RED}Skipping $video_id - format fail${RESET}" >&2
      echo >&3
      exit
    fi

    # Predict final filename
    final_file=$(yt-dlp \
      --get-filename \
      -f "${video_format}+${audio_format}" \
      -o "%(upload_date)s %(title)s.%(ext)s" \
      "$full_url" -4)

    # Download with archive check & resume support
    if ! yt-dlp \
        --continue \
        --download-archive "$archive_file" \
        -f "${video_format}+${audio_format}" \
        -o "%(upload_date)s %(title)s.%(ext)s" \
        "$full_url" -4
    then
      # Retry if filename too long
      echo -e "\n${RED}Retrying with short filename...${RESET}" >&2
      yt-dlp \
        --continue \
        --download-archive "$archive_file" \
        -f "${video_format}+${audio_format}" \
        -o "%(upload_date)s %(title).85s.%(ext)s" \
        "$full_url" -4
    fi

    # Record ID -> filename map if not logged before
    if ! grep -q "^$video_id |" "$id_map_file" 2>/dev/null; then
      echo "$video_id | $final_file" >> "$id_map_file"
    fi

    # Completion log
    echo -e "\n${GREEN}Downloaded ${current}/${total} (${video_id})${RESET}"

    # Release job token
    echo >&3
  } &
done

# Wait for all background jobs
wait

echo -e "\n${GREEN}All done!${RESET}"
