#!/usr/bin/env bash
set -euo pipefail

########################################
#  Parse options
########################################
PAUSE=0
if [[ "${1:-}" == "--with-pause" ]]; then
  PAUSE=1
  echo "PAUSE ENABLED: Will pause after mounting for inspection."
  shift
fi

########################################
#  Root escalation
########################################
if (( EUID != 0 )); then
  echo "This script needs root; re-running with sudo..."
  exec sudo -E "$0" "$@"
fi

########################################
#  Config
########################################
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UF2_DIR="$SCRIPT_ROOT/output"

# Disk label for Nice!Nano bootloader volume
DISK_LABEL="${DISK_LABEL:-NICENANO}"
FD="/dev/disk/by-label/$DISK_LABEL"

# Mount point for flashing
MOUNT_POINT="/mnt/nicenano"
POLL_INTERVAL=0.2          # seconds between device polls
SAFETY_DELAY_IF_PRESENT=20 # seconds before flashing if device already present

# UF2 paths (adjust if your filenames differ)
LEFT_CUSTOM="$UF2_DIR/left-custom.uf2"
RIGHT_CUSTOM="$UF2_DIR/right-custom.uf2"

LEFT_TRAVEL="$UF2_DIR/left-travel.uf2"
RIGHT_TRAVEL="$UF2_DIR/right-travel.uf2"

RESET_CUSTOM="$UF2_DIR/settings_reset-custom.uf2"
RESET_TRAVEL="$UF2_DIR/settings_reset-travel.uf2"

mkdir -p "$MOUNT_POINT"

########################################
#  Helpers
########################################

wait_for_device_appear() {
  echo "  Waiting for $FD to appear (bootloader mode)..."
  while [[ ! -b "$FD" ]]; do
    sleep "$POLL_INTERVAL"
  done
  echo "  Detected $FD."
}

wait_for_device_disappear() {
  echo "  Waiting for $FD to disappear (unplug / exit bootloader)..."
  while [[ -b "$FD" ]]; do
    sleep "$POLL_INTERVAL"
  done
}

countdown_seconds() {
  local seconds="$1"
  for ((i=seconds; i>0; i--)); do
    printf "  Flashing in %2d seconds... (unplug now to cancel)\r" "$i"
    sleep 1
  done
  echo "                                                  "
}

flash_uf2() {
  local uf2="$1"
  local label="$2"

  if [[ ! -f "$uf2" ]]; then
    echo "ERROR: UF2 file not found: $uf2"
    return 1
  fi

  echo
  echo "--------------------------------------------------"
  echo " $label"
  echo "--------------------------------------------------"
  echo "• Ensure correct half is plugged in and in bootloader mode"
  echo "• Waiting for device: $FD"
  echo

  # Wait until bootloader disk exists
  until [[ -b "$FD" ]]; do
    sleep "$POLL_INTERVAL"
  done
  echo "Detected $FD"

  # Resolve real block device (symlink safe)
  local realdev
  realdev="$(realpath "$FD" 2>/dev/null || echo "$FD")"
  echo "Using block device: $realdev"

  # Delay before mounting
  echo "Waiting 2 seconds before mounting..."
  sleep 2

  # Ensure mount dir exists
  mkdir -p "$MOUNT_POINT"

   # Mount
   echo "Mounting $realdev → $MOUNT_POINT"
   if ! mount "$realdev" "$MOUNT_POINT"; then
     echo "ERROR: mount failed"
     return 1
   fi

   # Delay before copying
   echo "Mount OK — waiting 8 seconds before copying..."
   sleep 8

   # Pause if requested
   if (( PAUSE )); then
     echo
     echo "PAUSE: Inspect the mounted device."
     echo "UF2 path: $uf2"
     echo "Mount path: $MOUNT_POINT"
     echo "Manual copy command: sudo cp \"$uf2\" \"$MOUNT_POINT/\""
     echo
     echo "Press Enter to continue flashing, or Ctrl+C to abort..."
     read
   fi

   # Copy
  local base
  base="$(basename "$uf2")"
  echo "Copying $base → $MOUNT_POINT"
  if ! cp -v "$uf2" "$MOUNT_POINT/"; then
    echo "ERROR: copy failed"
    umount "$MOUNT_POINT" || true
    return 1
  fi

  sync

  # Delay after copy before unmount
  echo "Waiting 2 seconds before unmounting..."
  sleep 2

  echo "Unmounting..."
  umount "$MOUNT_POINT" || echo "Warning: unmount failed or FS disappeared early"

  echo "Flash command completed for: $label"
  echo "Waiting for device to disappear…"
  while [[ -b "$realdev" ]]; do
    sleep "$POLL_INTERVAL"
  done
  echo "Device disappeared — this half is done."
  echo
}

# Mode A: normal flash only (flash-* options)
flash_half_only() {
  local layout_uf2="$1"
  local side="$2"     # LEFT / RIGHT
  local profile="$3"  # custom / travel

  flash_uf2 "$layout_uf2" "$side ($profile firmware)"
}

# Mode B: reset then flash (reset-* options)
reset_then_flash_half() {
  local reset_uf2="$1"
  local layout_uf2="$2"
  local side="$3"     # LEFT / RIGHT
  local profile="$4"  # custom / travel

  # 1) Reset settings first
  flash_uf2 "$reset_uf2" "$side ($profile settings_reset FIRST)"

  # 2) Then flash layout firmware
  echo "Now re-enter bootloader on the SAME half ($side) to flash firmware ($profile)."
  flash_uf2 "$layout_uf2" "$side ($profile firmware AFTER reset)"
}

########################################
#  High-level flows
########################################

do_flash_custom() {
  echo
  echo ">>> flash-custom"
  echo "    For each half: flash CUSTOM firmware (no reset)."
  flash_half_only "$LEFT_CUSTOM"  "LEFT"  "custom"
  echo "Switch to the RIGHT half and plug it in."
  flash_half_only "$RIGHT_CUSTOM" "RIGHT" "custom"
  echo "flash-custom complete."
}

do_flash_travel() {
  echo
  echo ">>> flash-travel"
  echo "    For each half: flash TRAVEL firmware (no reset)."
  flash_half_only "$LEFT_TRAVEL"  "LEFT"  "travel"
  echo "Switch to the RIGHT half and plug it in."
  flash_half_only "$RIGHT_TRAVEL" "RIGHT" "travel"
  echo "flash-travel complete."
}

do_reset_custom() {
  echo
  echo ">>> reset-custom"
  echo "    For each half: settings_reset-custom FIRST, then CUSTOM firmware."
  reset_then_flash_half "$RESET_CUSTOM" "$LEFT_CUSTOM"  "LEFT"  "custom"
  echo "Switch to the RIGHT half and plug it in."
  reset_then_flash_half "$RESET_CUSTOM" "$RIGHT_CUSTOM" "RIGHT" "custom"
  echo "reset-custom complete."
}

do_reset_travel() {
  echo
  echo ">>> reset-travel"
  echo "    For each half: settings_reset-travel FIRST, then TRAVEL firmware."
  reset_then_flash_half "$RESET_TRAVEL" "$LEFT_TRAVEL"  "LEFT"  "travel"
  echo "Switch to the RIGHT half and plug it in."
  reset_then_flash_half "$RESET_TRAVEL" "$RIGHT_TRAVEL" "RIGHT" "travel"
  echo "reset-travel complete."
}

########################################
#  Menu
########################################

while true; do
  cat <<EOF

========== ZMK Flash Menu ==========
1) Exit
2) flash-custom
     LEFT : left-custom.uf2
     RIGHT: right-custom.uf2
3) flash-travel
     LEFT : left-travel.uf2
     RIGHT: right-travel.uf2
4) reset-custom
     LEFT : settings_reset-custom.uf2 -> left-custom.uf2
     RIGHT: settings_reset-custom.uf2 -> right-custom.uf2
5) reset-travel
     LEFT : settings_reset-travel.uf2 -> left-travel.uf2
     RIGHT: settings_reset-travel.uf2 -> right-travel.uf2
====================================
EOF

  read -rp "Choose an option [1-5]: " choice
  case "$choice" in
    1|q|Q|exit|Exit)
      echo "Exiting."
      exit 0
      ;;
    2)
      do_flash_custom
      exit 0
      ;;
    3)
      do_flash_travel
      exit 0
      ;;
    4)
      do_reset_custom
      exit 0
      ;;
    5)
      do_reset_travel
      exit 0
      ;;
    *)
      echo "Invalid choice: $choice"
      ;;
  esac
done

