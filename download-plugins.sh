#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$1"
BEPINEX_DIR="$APP_DIR/BepInEx"
MODS_DIR="$BEPINEX_DIR/plugins"
LIST_FILE="/home/steam/plugin-list"

# ===============================================================
# Debugging
# ===============================================================

echo "APP_DIR=$APP_DIR"
echo "BEPINEX_DIR=$BEPINEX_DIR"
echo "MODS_DIR=$MODS_DIR"
echo "LIST_FILE=$LIST_FILE"

# ===============================================================
# Helpers
# ===============================================================

get_plugin_info() {
  local plugin="$1"
  local json_url="https://thunderstore.io/api/experimental/package/${plugin}"
  curl -sfSL -H "accept: application/json" "$json_url"
}

download_and_extract() {
  local url="$1"
  local target_dir="$2"
  local filename tmp_extract_dir

  filename="$(basename "$url")"
  tmp_extract_dir="$(mktemp -d)"

  mkdir -p "$target_dir"

  echo "⬇️  Downloading $filename..."
  curl -sfSL -o "/tmp/$filename" "$url"

  echo "📦 Extracting $filename..."
  unzip -o -q "/tmp/$filename" -d "$tmp_extract_dir"

  echo "📂 Collecting .dll files..."
  find "$tmp_extract_dir" -type f -iname "*.dll" -exec mv -f {} "$target_dir/" \;

  # Cleanup
  rm -rf "$tmp_extract_dir"
  rm -f "/tmp/$filename"
}

download_and_extract_bepinex() {
  local url="$1"
  local target_dir="$2"
  local filename tmp_extract_dir

  filename="$(basename "$url")"
  tmp_extract_dir="$(mktemp -d)"

  mkdir -p "$target_dir"

  echo "⬇️  Downloading $filename..."
  curl -sfSL -o "/tmp/$filename" "$url"

  echo "📦 Extracting $filename..."
  unzip -o -q "/tmp/$filename" -d "$tmp_extract_dir"

  echo "📂 Installing BepInEx contents..."
  # Move everything from the inner folder into target_dir
  rsync -a "$tmp_extract_dir"/BepInExPack_Valheim/ "$target_dir"/

  # Cleanup
  rm -rf "$tmp_extract_dir"
  rm -f "/tmp/$filename"
}

# ===============================================================
# Plugin installation (with dependency resolution)
# ===============================================================
install_plugin() {
  local plugin="$1"
  local mods_dir="$2"
  local json json_download_url version author plugin_name filename

  echo "🔍 Checking plugin: $plugin"

  json="$(get_plugin_info "$plugin")" || {
    echo "❌ Failed to fetch info for $plugin"
    return
  }

  json_download_url="$(echo "$json" | jq -r '.latest.download_url // empty')"
  version="$(echo "$json" | jq -r '.latest.version_number // "unknown"')"
  author="$(echo "$plugin" | cut -d'/' -f1)"
  plugin_name="$(echo "$plugin" | cut -d'/' -f2)"
  filename="${author}-${plugin_name}-${version}.zip"

  local install_marker="${mods_dir}/${author}-${plugin_name}.version"

  # Download and install plugin
  if [[ -n "$json_download_url" ]]; then
    if [[ "$plugin_name" == *BepInEx* ]]; then
      download_and_extract_bepinex "$json_download_url" "$mods_dir"
    else
      download_and_extract "$json_download_url" "$mods_dir"
    fi
    echo "$version" > "$install_marker"
    echo "✅ Installed ${plugin_name} v${version}"
  else
    echo "⚠️  No download URL for ${plugin_name}"
    return
  fi

  # Handle dependencies recursively
  local dependencies
  dependencies=$(echo "$json" | jq -r '.latest.dependencies[]?' || true)
  for dep in $dependencies; do
    # Format is "author-name-version"
    local dep_author dep_name dep_ver dep_id
    dep_author=$(echo "$dep" | cut -d'-' -f1)
    dep_name=$(echo "$dep" | cut -d'-' -f2)
    dep_ver=$(echo "$dep" | cut -d'-' -f3)
    dep_id="${dep_author}/${dep_name}"

    # Skip BepInEx dependencies, it should already be installed
    if [[ "$dep_name" == *BepInEx* ]]; then
      echo "⏭️ Skipping dependency: $dep_id"
      continue
    fi

    echo "🔗 Checking dependency: $dep_id (requires >= $dep_ver)"
    install_plugin "$dep_id" "$mods_dir"
  done
}

# ===============================================================
# Step 1: BepInEx installation
# ===============================================================
install_bepinex() {
  #local url="https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/5.4.2333/"
  echo "🔧 Installing BepInEx...a better way..."

  plugin=denikson/BepInExPack_Valheim 

  # a better way, APP_DIR should be root valheim dir.
  install_plugin "$plugin" "$APP_DIR"


#  download_and_extract "$url" "/tmp"

#  rsync -a /tmp/BepInExPack_Valheim/ $APP_DIR/

#  rm -rf /tmp/BepInExPack_Valheim

  chmod +x $APP_DIR/*.sh

  echo "✅ BepInEx installed in: $APP_DIR"
}

# ===============================================================
# Step 2: Process plugin list
# ===============================================================
download_plugins() {
  # first, clean the plugin dir.  Always download latest.
  if [[ -d "$MODS_DIR" ]]; then
    echo "Cleaning plugin directory (deleting plugins)."
    rm -rf $MODS_DIR/*
  else
    echo "$MODS_DIR not found, skipping cleaning..."
  fi

  if [[ ! -f "$LIST_FILE" ]]; then
    echo "⚠️ Plugin list not found: $LIST_FILE (skipping)"
    return
  fi

  local valid_lines
  valid_lines=$(grep -v '^\s*#' "$LIST_FILE" | grep -v '^\s*$' || true)

  if [[ -z "$valid_lines" ]]; then
    echo "⚠️ Plugin list is empty or all comments (skipping)"
    return
  fi

  echo "📦 Processing plugins from: $LIST_FILE"
  echo "$valid_lines" | while read -r plugin; do
    [[ -z "$plugin" ]] && continue
    install_plugin "$plugin" "$MODS_DIR"
  done

  echo "✅ Plugin processing complete."
}

# ===============================================================
# MAIN
# ===============================================================
install_bepinex
download_plugins
