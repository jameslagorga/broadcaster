#!/bin/bash
set -exo pipefail

main() {
    echo "Starting broadcaster job"

    # Twitch Ingest Server
    INGEST_SERVER="rtmp://live.twitch.tv/app/"

    # Check if VIDEO_DIRECTORY is set
    if [ -z "$VIDEO_DIRECTORY" ]; then
      echo "ERROR: VIDEO_DIRECTORY environment variable is not set."
      exit 1
    fi

    # Create a playlist file for ffmpeg
    PLAYLIST_FILE="/tmp/playlist.txt"
    echo "Searching for .mp4 files in ${VIDEO_DIRECTORY}"
    find "$VIDEO_DIRECTORY" -name "*.mp4" -print0 | while IFS= read -r -d $'\0' file;
 do
        echo "file '$file'" >> "$PLAYLIST_FILE"
    done

    # Check if the playlist is empty
    if [ ! -s "$PLAYLIST_FILE" ]; then
        echo "ERROR: No .mp4 files found in $VIDEO_DIRECTORY"
        exit 1
    fi

    echo "Found $(wc -l < "$PLAYLIST_FILE") video(s) to stream."
    echo "Starting ffmpeg stream..."

    # Create a named pipe for smooth streaming
    PIPE_FILE="/tmp/stream.pipe"
    mkfifo "$PIPE_FILE"

    # First ffmpeg process: Concatenate and output to pipe, preserving timestamps
    ffmpeg -err_detect ignore_err -f concat -safe 0 -i "$PLAYLIST_FILE" -y -c copy -copyts -f mpegts "$PIPE_FILE" &

    # Second ffmpeg process: Read from pipe, encode, and stream to Twitch, ignoring timestamp issues
    ffmpeg -fflags +igndts -i "$PIPE_FILE" -f lavfi -i anullsrc \
      -map 0:v:0 -map 1:a:0 \
      -c:v libx264 -preset veryfast -crf 23 -maxrate 4500k -bufsize 9000k \
      -c:a aac -b:a 160k -shortest \
      -f flv "${INGEST_SERVER}${TWITCH_STREAM_KEY}"

    echo "Finished broadcaster job"
}

main
