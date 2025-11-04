#!/bin/bash
set -euo pipefail

MODS_DIR=$1

PLUGINLIST="${PLUGINLIST:-/home/steam}"
LIST_FILE="${PLUGINLIST}/plugin-list"
DEPENDENCIES=""

# If plugin list doesn't exist, skip and continue
if [[ ! -f "$LIST_FILE" ]]; then
  echo "⚠️ Plugin list not found: $LIST_FILE (skipping)"
else

# Filter out empty/comment lines to see if there’s anything to do
VALID_LINES=$(grep -v '^\s*#' "$LIST_FILE" | grep -v '^\s*$' || true)

if [[ -z "$VALID_LINES" ]]; then
  echo "⚠️ Plugin list is empty or all comments (skipping)"
  exit 0
fi

echo "📦 Processing plugins from: $LIST_FILE"

# Loop through each valid plugin line
echo "$VALID_LINES" | while read -r PLUGIN; do
  echo "🔍 Checking plugin: $PLUGIN"
  JSON_URL="https://thunderstore.io/api/experimental/package/${PLUGIN}"
  JSON=$(curl  -sfSL -H "accept: application/json" "$JSON_URL")

  DOWNLOAD_URL=$(echo "$JSON" | jq -r '.latest.download_url // empty')
  DEPENDENCIES=$DEPENDENCIES$(echo "$JSON" | jq -r '.latest.dependencies // empty')

  echo $DEPENDENCIES
  for i in $DEPENDENCIES;
    do
      echo "DEPENDENCY FOUND: $i";
  done


  if [[ -n "$DOWNLOAD_URL" ]]; then
    echo "⬇️  Found: $DOWNLOAD_URL"
    VERSION=$(echo "$JSON" | jq -r '.latest.version_number // "unknown"')
    AUTHOR=$(echo "$PLUGIN" | cut -d'/' -f1)
    PLUGIN_NAME=$(echo "$PLUGIN" | cut -d'/' -f2)

    FILENAME="${AUTHOR}-${PLUGIN_NAME}-${VERSION}.zip"

#    mkdir -p "${PLUGINLIST}/downloads"
    cd "${MODS_DIR}"
    curl -sfSL -o $FILENAME "$DOWNLOAD_URL"
    ls -al
  else
    echo "⚠️  No download URL found for ${PLUGIN}"
  fi
done

echo "✅ Plugin processing complete."
fi

