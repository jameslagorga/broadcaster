#!/bin/bash

# Check if jq and kubectl are installed
if ! command -v jq &> /dev/null || ! command -v kubectl &> /dev/null; then
    echo "jq and kubectl are required. Please install them to run this script."
    echo "On macOS, you can install jq with: brew install jq"
    echo "For kubectl, refer to Kubernetes documentation."
    exit 1
fi

# The IP address of your RTMP server
RTMP_IP="34.168.74.11"

# The base URL for the RTMP server
RTMP_URL="rtmp://${RTMP_IP}:1935/live"

# Set a stream name (e.g., 'main-event', 'side-stage').
# This will be used in the GCS bucket path: gs://multi-camera-streams/<STREAM_NAME>/camera-#/
STREAM_NAME="dexterityro"

# --- PRE-FLIGHT CLEANUP ---
echo "--- Ensuring a clean start ---"
echo "Terminating any existing ffmpeg processes..."
killall ffmpeg > /dev/null 2>&1 || true
sleep 1
echo "Clearing previous HLS stream data from NFS..."
kubectl exec shell -- /bin/bash -c "rm -rf /mnt/nfs/hls/*"
if [ $? -ne 0 ]; then
    echo "Warning: Failed to clear HLS directory. The 'shell' pod might not be running or accessible."
    echo "Please ensure 'kubectl get pods | grep shell' shows a running pod."
fi
echo

# Find the indices of the "HD Pro Webcam C920" cameras using system_profiler and jq
CAMERA_INDICES=($(system_profiler SPCameraDataType -json | jq '.SPCameraDataType | to_entries | .[] | select(.value._name == "HD Pro Webcam C920") | .key'))

# Check if any cameras were found
if [ ${#CAMERA_INDICES[@]} -eq 0 ]; then
    echo "No 'HD Pro Webcam C920' cameras found."
    exit 1
fi

echo "Found cameras at indices: ${CAMERA_INDICES[*]}"

# File to store the PIDs of the ffmpeg processes
PID_FILE="pids.txt"
> "$PID_FILE" # Clear the PID file

# Loop through the camera indices and start a streaming process for each
for index in "${CAMERA_INDICES[@]}"; do
  STREAM_KEY="${STREAM_NAME}_camera-${index}"
  echo "Starting stream for camera ${index} with stream key ${STREAM_KEY} (1080p -> 720p, CRF 28)"
  
  # Start ffmpeg in the background using nohup to ensure it keeps running
  nohup ffmpeg -f avfoundation -video_size 1920x1080 -framerate 30 -use_wallclock_as_timestamps 1 -i "$index:none" \
    -vf "scale=1280:720,format=yuv420p" \
    -c:v libx264 -preset ultrafast -tune zerolatency -crf 28 \
    -pix_fmt yuv420p -r 30 \
    -f flv "${RTMP_URL}/${STREAM_KEY}" > /dev/null 2>&1 &
  
  # Save the PID of the last background process
  echo $! >> "$PID_FILE"
done

echo "All camera streams started. PIDs are in ${PID_FILE}."
echo "To stop the streams, run: kill \$(cat \"${PID_FILE}\")"
