#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$1"
MODS_DIR="$APP_DIR/BepInEx/plugins"
LIST_FILE="/home/steam/plugin-list"

# ===============================================================
# Helpers
# ===============================================================

version_compare() {
  # returns 0 if $1 == $2, 1 if $1 > $2, 2 if $1 < $2
  if [[ "$1" == "$2" ]]; then return 0; fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do ver1[i]=0; done
  for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do ver2[i]=0; done
  for ((i=0; i<${#ver1[@]}; i++)); do
    if ((10#${ver1[i]} > 10#${ver2[i]})); then return 1; fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then return 2; fi
  done
  return 0
}

get_plugin_info() {
  local plugin="$1"
  local json_url="https://thunderstore.io/api/experimental/package/${plugin}"
  curl -sfSL -H "accept: application/json" "$json_url"
}

download_and_extract() {
  local url="$1"
  local target_dir="$2"
  local filename
  filename="$(basename "$url")"

  mkdir -p "$target_dir"
  echo "⬇️  Downloading $filename..."
  curl -sfSL -o "/tmp/$filename" "$url"
  echo "📦 Extracting $filename to $target_dir..."
  unzip -o -q "/tmp/$filename" -d "$target_dir"
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

  # Check existing version
  if [[ -f "$install_marker" ]]; then
    local existing_version
    existing_version=$(<"$install_marker")
    version_compare "$version" "$existing_version"
    cmp_result=$?
    if [[ $cmp_result -eq 2 ]]; then
      echo "🟡 Installed version ($existing_version) is newer — skipping ${plugin_name}"
      return
    elif [[ $cmp_result -eq 0 ]]; then
      echo "✔️  ${plugin_name} v${version} already installed."
      return
    else
      echo "⬆️  Updating ${plugin_name} from ${existing_version} → ${version}"
    fi
  fi

  # Download and install plugin
  if [[ -n "$json_download_url" ]]; then
    download_and_extract "$json_download_url" "$mods_dir"
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

    echo "🔗 Checking dependency: $dep_id (requires >= $dep_ver)"
    install_plugin "$dep_id" "$mods_dir"
  done
}

# ===============================================================
# Step 1: BepInEx installation
# ===============================================================
install_bepinex() {
  local url="https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/5.4.2333/"
  echo "🔧 Installing BepInEx..."
  download_and_extract "$url" "/tmp"

  rsync -a /tmp/BepInExPack_Valheim/ $APP_DIR/

  rm -rf /tmp/BepInExPack_Valheim
  chmod +x $APP_DIR/*.sh

#  export LD_PRELOAD="/opt/valheim/doorstop_libs/libdoorstop_x64.so"
#  export DOORSTOP_ENABLED=1
#  export DOORSTOP_TARGET_ASSEMBLY=./BepInEx/core/BepInEx.Preloader.dll
#  export LD_LIBRARY_PATH="./doorstop_libs:$LD_LIBRARY_PATH"
#  export LD_PRELOAD="libdoorstop_x64.so:$LD_PRELOAD"
#  export LD_LIBRARY_PATH="./linux64:$LD_LIBRARY_PATH"

  echo "✅ BepInEx installed in: $APP_DIR"
}

# ===============================================================
# Step 2: Process plugin list
# ===============================================================
download_plugins() {
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
