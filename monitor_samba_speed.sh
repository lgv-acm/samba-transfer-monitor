#!/bin/bash

# Load environment variables from .env file
# shellcheck source=.env
if [[ ! -f "$(dirname "$0")/.env" ]]; then
    echo "Error: .env file not found. Copy .env.example to .env and fill in your values." >&2
    exit 1
fi
set -a; source "$(dirname "$0")/.env"; set +a

# Unique test filename per run (uses PID to avoid collisions)
TEST_FILE="testfile_$$.tmp"

# Full path to local test file
LOCAL_FILE="$LOCAL_TMP/$TEST_FILE"

# smbclient base command with authentication and remote directory
SMBCLIENT="smbclient //$SERVER/$SHARE -U $USER%$PASSWORD -D $REMOTE_TMP"

# ----------- SCRIPT START -----------

# Create local temporary directory if needed
mkdir -p "$LOCAL_TMP"

# Generate a random test file of the configured size
dd if=/dev/urandom of="$LOCAL_FILE" bs=1M count="$FILE_SIZE_MB" status=none

# Write CSV header only if the output file does not already exist
if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "timestamp,operation,filesize_MB,duration_sec,speed_MBps" > "$OUTPUT_FILE"
fi

# Log a result row to the CSV file
log_result() {
    local operation="$1"
    local size="$2"
    local duration="$3"
    local speed="$4"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$ts,$operation,$size,$duration,$speed" >> "$OUTPUT_FILE"
}

# --- Upload test ---
start_time=$(date +%s.%N)
printf 'put %s %s\n' "$LOCAL_FILE" "$TEST_FILE" | $SMBCLIENT > /dev/null 2>&1
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
speed=$(echo "scale=2; $FILE_SIZE_MB / $duration" | bc)
log_result "upload" "$FILE_SIZE_MB" "$duration" "$speed"

# --- Download test ---
start_time=$(date +%s.%N)
printf 'get %s %s\n' "$TEST_FILE" "${LOCAL_FILE}.download" | $SMBCLIENT > /dev/null 2>&1
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
speed=$(echo "scale=2; $FILE_SIZE_MB / $duration" | bc)
log_result "download" "$FILE_SIZE_MB" "$duration" "$speed"

# --- Cleanup: remove remote test file ---
printf 'del %s\n' "$TEST_FILE" | $SMBCLIENT > /dev/null 2>&1

# --- Cleanup: remove local test files ---
rm -f "$LOCAL_FILE" "${LOCAL_FILE}.download"

echo "Transfer speed test complete. Results appended to $OUTPUT_FILE."
