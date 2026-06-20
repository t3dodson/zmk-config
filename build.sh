#!/usr/bin/env bash

# nix develop

set -e  # Exit on error


### Variables

BOARD="nice_nano@2.0.0/nrf52840/zmk"

REPO_DIR="$(pwd)"
APP_DIR="$REPO_DIR/zmk/app"
CONFIG_DIR="$REPO_DIR/config"
#EXTRA_MODULES="$REPO_DIR/custom-modules"  # Adjust if you have extra modules
EXTRA_MODULES=""
BUILD_DIR="$REPO_DIR/build"
OUTPUT_DIR="$REPO_DIR/output"

# Shields directly from your config
SHIELDS_LEFT="corne_left nice_view_adapter nice_view_gem"
SHIELDS_RIGHT="corne_right nice_view_adapter nice_view_gem"
SHIELDS_SETTINGS="settings_reset"

### Clean build dirs
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

## Clean
if [ -d "$REPO_DIR/.west" ]; then
  rm -rf "$REPO_DIR/.west"
fi

### west init/update (only needed once, safe to re-run)
west init -l config
west update
west zephyr-export

export CMAKE_PREFIX_PATH="$REPO_DIR/zephyr:$CMAKE_PREFIX_PATH"

MY_BOARD_SUFFIXES=("custom" "travel")

for SUFFIX in "${MY_BOARD_SUFFIXES[@]}"; do

 	LEFT="left-${SUFFIX}"
 	RIGHT="right-${SUFFIX}"
 	SETTINGS_RESET="settings_reset-${SUFFIX}"

	### Create temporary corne.conf symlink for this profile
	rm -f "$CONFIG_DIR/corne.conf"
	ln -s "corne-${SUFFIX}.conf" "$CONFIG_DIR/corne.conf"
	echo "Building $SUFFIX profile (using corne-${SUFFIX}.conf)..."

 	### Build left side
  	west build -d "$BUILD_DIR/$LEFT" -p -b "$BOARD" \
  	  -s "$APP_DIR" \
  	  -- -DSHIELD="$SHIELDS_LEFT" \
 	      -DZMK_CONFIG="$CONFIG_DIR" \
 	      -DZMK_EXTRA_MODULES="$EXTRA_MODULES"

 	### Build right side
  	west build -d "$BUILD_DIR/$RIGHT" -p -b "$BOARD" \
  	  -s "$APP_DIR" \
  	  -- -DSHIELD="$SHIELDS_RIGHT" \
 	      -DZMK_CONFIG="$CONFIG_DIR" \
 	      -DZMK_EXTRA_MODULES="$EXTRA_MODULES"

 	### Build settings_reset
  	west build -d "$BUILD_DIR/$SETTINGS_RESET" -p -b "$BOARD" \
  	  -s "$APP_DIR" \
 	  -- -DSHIELD="$SHIELDS_SETTINGS" \
 	      -DZMK_CONFIG="$CONFIG_DIR" \
 	      -DZMK_EXTRA_MODULES="$EXTRA_MODULES"

	### Copy output firmware files
	cp "$BUILD_DIR/$LEFT/zephyr/zmk.uf2" "$OUTPUT_DIR/$LEFT.uf2"
	cp "$BUILD_DIR/$RIGHT/zephyr/zmk.uf2" "$OUTPUT_DIR/$RIGHT.uf2"
	cp "$BUILD_DIR/$SETTINGS_RESET/zephyr/zmk.uf2" "$OUTPUT_DIR/$SETTINGS_RESET.uf2"

	### Clean up temporary symlink
	rm -f "$CONFIG_DIR/corne.conf"

done
echo "✅ Build complete. Output files in: $OUTPUT_DIR"

