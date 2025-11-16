#!/usr/bin/env bash
set -euo pipefail

# https://www.valheimgame.com/support/a-guide-to-dedicated-servers/
#
# adminlist.txt found here:
# /root/.config/unity3d/IronGate/Valheim
#
  echo "******"
  echo "******"
  echo "******"
  echo "******"

  export LD_LIBRARY_PATH=/opt/valheim/linux64

# env defaults (can be overridden)
: "${ADMINLIST_IDS:=}"
: "${STEAMCMD_DIR:=$HOME}"
: "${APP_DIR:=/opt/valheim}"
: "${STEAM_APP_ID:=896660}" 
: "${SERVER_NAME:=My-Server}"
: "${WORLD_NAME:=Dedicated}"
: "${SERVER_PASS:=changeme}"
: "${SERVER_PUBLIC:=1}"   # 1 = listed on server list, 0 = private
: "${SERVER_PORT:=2456}"
#: "${PORT_END:=2458}"
: "${INSTALL_PLUGINS:=false}"   # optional: URL to a BepInEx zip
: "${WORLD_SAVE_DIR:=${APP_DIR}/worlds}"
: "${BACKUP_DIR:=${APP_DIR}/backups}"

# Ensure directories exist and are writable
mkdir -p /data /data/worlds /data/config /data/backups

cd "${STEAMCMD_DIR}"
#
# Update/install Valheim server via steamcmd
echo "*** Updating/installing Valheim server via steamcmd..."
steamcmd +force_install_dir "${APP_DIR}" +login anonymous +app_update ${STEAM_APP_ID} validate +quit

# If mounted world or config exist in /data, link them into the game folder
# Typical Valheim files: world files (*.fwl, *.db), and start configuration files
# Symlink adminlist.txt if not already linked
if [ -d /data/worlds ]; then
  ln -sfn /data/worlds "${WORLD_SAVE_DIR}" || true
  if [ ! -L /data/worlds/adminlist.txt ]; then
    ln -sf /opt/valheim/config/adminlist.txt /data/worlds/adminlist.txt
  fi
fi
ln -sf /opt/valheim/config/plugin-list /home/steam/plugin-list
#if [ -d /data/config ]; then
#  ln -sfn /data/config "${APP_DIR}/config" || true
#fi
if [ -d /data/backups ]; then
  ln -sfn /data/backups "${BACKUP_DIR}" || true
fi

if [ -n "${INSTALL_PLUGINS}" ]; then
  echo ""
  echo "***************************"
  echo "*** Checking plugins... ***"
  echo "***************************"
  echo ""
  /home/steam/download-plugins.sh $APP_DIR || true
  echo ""
  echo "***************************"
  echo "**** DONE with plugins ****"
  echo "***************************"
  echo ""

  export LD_PRELOAD="$APP_DIR/doorstop_libs/libdoorstop_x64.so"
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY=$APP_DIR/BepInEx/core/BepInEx.Preloader.dll
  export LD_LIBRARY_PATH="$APP_DIR/doorstop_libs:$LD_LIBRARY_PATH"
#  export LD_PRELOAD="$APP_DIR/doorstop_libs/libdoorstop_x64.so:$LD_PRELOAD"

fi

# Expose helpful info
echo "****"
echo "Server name: ${SERVER_NAME}"
echo "World: ${WORLD_NAME}"
echo "Port: ${SERVER_PORT} (UDP ${SERVER_PORT}..$((SERVER_PORT+2)))"
echo "Public: ${SERVER_PUBLIC}"
echo "****"

# Build the command and run Valheim server
SERVER_BIN="${APP_DIR}/valheim_server.x86_64"
if [ ! -x "${SERVER_BIN}" ]; then
  echo "*** Error: server binary not found at ${SERVER_BIN}"
  exit 2
fi

echo "*** Starting dedicated server ***"

#cd $APP_DIR

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
  -public "${SERVER_PUBLIC}" \
  -savedir "${WORLD_SAVE_DIR}" \
  -saveinterval 1800 \
  -backups 4 
#  -preset "hard"
#      Setting a preset will override all modifiers (if any are set)
#      Normal, Casual, Easy, Hard, Hardcore, Immersive, Hammer
#  -modifier raids none 
#      Sets chosen world modifier with value. If
#      combined with a preset should be set after. Valid
#      modifiers and values are:
#      Combat: veryeasy, easy, hard, veryhard
#      DeathPenalty: casual, veryeasy, easy, hard,
#      hardcore
#      Resources: muchless, less, more, muchmore, most
#      Raids: none, muchless, less, more, muchmore
#      Portals: casual, hard, veryhard
#  -setkey nomap
#      Sets a world modifier checkbox key. Valid values are: 
#      nobuildcost, playerevents, passivemobs, nomap
  

