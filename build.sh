#!/usr/bin/env bash

# nix develop

set -e  # Exit on error


### Variables

BOARD="nice_nano_v2"

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

### Build left side
west build -d "$BUILD_DIR/left" -p -b "$BOARD" \
  -s "$APP_DIR" \
  -- -DSHIELD="$SHIELDS_LEFT" \
      -DZMK_CONFIG="$CONFIG_DIR" \
      -DZMK_EXTRA_MODULES="$EXTRA_MODULES"

### Build right side
west build -d "$BUILD_DIR/right" -p -b "$BOARD" \
  -s "$APP_DIR" \
  -- -DSHIELD="$SHIELDS_RIGHT" \
      -DZMK_CONFIG="$CONFIG_DIR" \
      -DZMK_EXTRA_MODULES="$EXTRA_MODULES"

### Build settings_reset
west build -d "$BUILD_DIR/settings_reset" -p -b "$BOARD" \
  -s "$APP_DIR" \
  -- -DSHIELD="$SHIELDS_SETTINGS" \
      -DZMK_CONFIG="$CONFIG_DIR" \
      -DZMK_EXTRA_MODULES="$EXTRA_MODULES"

### Copy output firmware files
cp "$BUILD_DIR/left/zephyr/zmk.uf2" "$OUTPUT_DIR/left.uf2"
cp "$BUILD_DIR/right/zephyr/zmk.uf2" "$OUTPUT_DIR/right.uf2"
cp "$BUILD_DIR/settings_reset/zephyr/zmk.uf2" "$OUTPUT_DIR/settings_reset.uf2"

echo "✅ Build complete. Output files in: $OUTPUT_DIR"

