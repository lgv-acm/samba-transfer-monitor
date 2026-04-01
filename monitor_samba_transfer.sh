#!/usr/bin/env bash

set -euo pipefail

# Configuration (can be overridden via environment variables)
SAMBA_SERVER="${SAMBA_SERVER:-192.168.1.10}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-}"
SAMPLE_INTERVAL_SECONDS="${SAMPLE_INTERVAL_SECONDS:-1}"
SAMPLE_COUNT="${SAMPLE_COUNT:-10}"
OUTPUT_FILE="${OUTPUT_FILE:-./samba_transfer_history.txt}"

HEADER="timestamp samba_server interface interval_seconds download_bytes_per_sec upload_bytes_per_sec download_mib_per_sec upload_mib_per_sec"

require_file() {
  local path="$1"
  if [[ ! -r "$path" ]]; then
    echo "Error: Cannot read required file: $path" >&2
    exit 1
  fi
}

detect_interface() {
  ip -o route get "$SAMBA_SERVER" 2>/dev/null | awk '{
    for (i=1; i<=NF; i++) {
      if ($i == "dev") {
        print $(i+1)
        exit
      }
    }
  }'
}

read_bytes() {
  local interface="$1"
  local kind="$2"
  local stat_file="/sys/class/net/${interface}/statistics/${kind}_bytes"
  require_file "$stat_file"
  cat "$stat_file"
}

to_mib_per_sec() {
  awk -v bytes_per_sec="$1" 'BEGIN { printf "%.6f", (bytes_per_sec / 1048576) }'
}

validate_positive_integer() {
  local value="$1"
  local name="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -eq 0 ]]; then
    echo "Error: $name must be a positive integer. Got: $value" >&2
    exit 1
  fi
}

main() {
  validate_positive_integer "$SAMPLE_INTERVAL_SECONDS" "SAMPLE_INTERVAL_SECONDS"
  validate_positive_integer "$SAMPLE_COUNT" "SAMPLE_COUNT"

  local interface="$NETWORK_INTERFACE"
  if [[ -z "$interface" ]]; then
    interface="$(detect_interface)"
    if [[ -z "$interface" ]]; then
      echo "Error: Unable to detect network interface for SAMBA_SERVER=$SAMBA_SERVER. Set NETWORK_INTERFACE explicitly." >&2
      exit 1
    fi
  fi

  if [[ ! -d "/sys/class/net/$interface" ]]; then
    echo "Error: Interface '$interface' does not exist on this system." >&2
    exit 1
  fi

  if [[ ! -f "$OUTPUT_FILE" ]] || [[ ! -s "$OUTPUT_FILE" ]]; then
    printf "%s\n" "$HEADER" > "$OUTPUT_FILE"
  fi

  local i=1
  while [[ "$i" -le "$SAMPLE_COUNT" ]]; do
    local rx_start tx_start rx_end tx_end
    rx_start="$(read_bytes "$interface" "rx")"
    tx_start="$(read_bytes "$interface" "tx")"

    sleep "$SAMPLE_INTERVAL_SECONDS"

    rx_end="$(read_bytes "$interface" "rx")"
    tx_end="$(read_bytes "$interface" "tx")"

    local download_bps upload_bps
    download_bps=$(( (rx_end - rx_start) / SAMPLE_INTERVAL_SECONDS ))
    upload_bps=$(( (tx_end - tx_start) / SAMPLE_INTERVAL_SECONDS ))

    local download_mib upload_mib timestamp
    download_mib="$(to_mib_per_sec "$download_bps")"
    upload_mib="$(to_mib_per_sec "$upload_bps")"
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    printf "%s %s %s %s %s %s %s %s\n" \
      "$timestamp" \
      "$SAMBA_SERVER" \
      "$interface" \
      "$SAMPLE_INTERVAL_SECONDS" \
      "$download_bps" \
      "$upload_bps" \
      "$download_mib" \
      "$upload_mib" >> "$OUTPUT_FILE"

    i=$((i + 1))
  done

  echo "Wrote $SAMPLE_COUNT sample(s) to $OUTPUT_FILE"
}

main "$@"
