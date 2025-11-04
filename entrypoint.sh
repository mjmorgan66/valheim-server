#!/usr/bin/env bash
set -euo pipefail

# env defaults (can be overridden)
: "${ADMINLIST_IDS:=}"
: "${STEAMCMD_DIR:=$HOME}"
: "${VALHEIM_DIR:=/opt/valheim}"
: "${VALHEIM_APP_ID:=896660}" 
: "${SERVER_NAME:=My-Server}"
: "${WORLD_NAME:=Dedicated}"
: "${SERVER_PASS:=changeme}"
: "${SERVER_PUBLIC:=1}"   # 1 = listed on server list, 0 = private
: "${SERVER_PORT:=2456}"
#: "${PORT_END:=2458}"
: "${BE_PINEX_URL:=}"   # optional: URL to a BepInEx zip
: "${MODS_DIR:=${VALHEIM_DIR}/BepInEx/plugins}"

# Ensure directories exist and are writable
mkdir -p /data /data/worlds /data/config ${MODS_DIR}
#chown -R "$(id -u)":"$(id -g)" /data
cd "${STEAMCMD_DIR}"
ls -al /home/steam
# Update/install Valheim server via steamcmd
echo "*** Updating/installing Valheim server via steamcmd..."
steamcmd +login anonymous +force_install_dir "${VALHEIM_DIR}" +app_update ${VALHEIM_APP_ID} validate +quit


# If user provided BEPINEX zip URL, download and install into valheim dir
if [ -n "${BE_PINEX_URL}" ]; then
  echo "*** Downloading and installing BepInEx from ${BE_PINEX_URL}..."
  tmpzip="bepinex-install.zip"
  curl -fsSL "${BE_PINEX_URL}" -o "${tmpzip}"
  unzip -o "${tmpzip}" -d "${VALHEIM_DIR}"
  rm -f "${tmpzip}"
  echo "*** BepInEx installed to ${VALHEIM_DIR}"

  echo ""
  echo "*** Checking plugins... ***"
  /home/steam/download-plugins.sh $MODS_DIR || true
  echo "*** DONE with plugins ***"
fi

# If mounted world or config exist in /data, link them into the game folder
# Typical Valheim files: world files (*.fwl, *.db), and start configuration files
if [ -d /data/worlds ]; then
  ln -sfn /data/worlds "${VALHEIM_DIR}/worlds" || true
fi
if [ -d /data/config ]; then
  ln -sfn /data/config "${VALHEIM_DIR}/config" || true
fi
# Ensure plugin dir exists
mkdir -p "${MODS_DIR}"

# Expose helpful info
echo "****"
echo "Server name: ${SERVER_NAME}"
echo "World: ${WORLD_NAME}"
echo "Port: ${SERVER_PORT} (UDP ${SERVER_PORT}..$((PORT+2)))"
echo "Public: ${SERVER_PUBLIC}"
echo "****"

# Build the command and run Valheim server
SERVER_BIN="${VALHEIM_DIR}/valheim_server.x86_64"
if [ ! -x "${SERVER_BIN}" ]; then
  echo "*** Error: server binary not found at ${SERVER_BIN}"
  exit 2
fi

echo "*** Starting dedicated server ***"

#cd $VALHEIM_DIR

#exec start_server.sh

# It must use the full valheim app id, and not the server app id
export SteamAppId=892970

# starts dedicated server
exec "${SERVER_BIN}" \
  -nographics \
  -batchmode \
  -name "${SERVER_NAME}" \
  -port "${SERVER_PORT}" \
  -world "${WORLD_NAME}" \
  -password "${SERVER_PASS}" \
  -public "${SERVER_PUBLIC}"

