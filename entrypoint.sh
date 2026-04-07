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
: "${BEPINEX_ROOT_DIR:=$APP_DIR/BepInEx}"
: "${BEPINEX_PLUGIN_CONFIG_DIR:=$BEPINEX_ROOT_DIR/config}"
: "${BEPINEX_PLUGIN_DIR:=$BEPINEX_ROOT_DIR/plugins}"
: "${CONFIG_FILE_DIR:=${APP_DIR}/config2}" # source folder to load config files to bepinex
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

###########
# PLUGINS #
###########
if [ -n "${INSTALL_PLUGINS}" ]; then
  echo ""
  echo "******************************"
  echo "*** Downloading plugins... ***"
  echo "******************************"
  echo "*"
  /home/steam/download-plugins.sh $APP_DIR || true
  echo "*"
  echo "* Done downloading plugins!"
  echo "*"
  echo "******************************"
  echo ""

  echo ""
  echo "*************************************"
  echo "***** Copy configs for plugins ******"
  echo "*************************************"
  echo "*"
  echo "* Copy dir: $CONFIG_FILE_DIR, cp Location: $BEPINEX_PLUGIN_CONFIG_DIR"
  echo "*"
  for i in $(ls $CONFIG_FILE_DIR 2>/dev/null); do echo "* Copying config file for $i"; cp -rf $CONFIG_FILE_DIR/$i  $BEPINEX_PLUGIN_CONFIG_DIR/$i; done
  echo "* Done copying configs!"
  echo "*"
  echo "*************************************"
  echo ""

  echo ""
  echo "*********************************"
  echo "*** Checking for AntiCheat... ***"
  echo "*********************************"
  echo "*"
  if [ -d "$BEPINEX_PLUGIN_CONFIG_DIR/AzuAntiCheat_Whitelist" ]; then
    echo "* Found Whitelist dir"
    echo "* Emtpying existing white list..."
    rm -rf $BEPINEX_PLUGIN_CONFIG_DIR/AzuAntiCheat_Whitelist/*
    echo "* Done!"
    echo "* Adding plugins to the whitelist..."
    for file in "$BEPINEX_PLUGIN_DIR"/*.dll; do
      [ -e "$file" ] || continue  # skip if no .dll files found
      echo "* Copying file $file to $BEPINEX_PLUGIN_CONFIG_DIR/AzuAntiCheat_Whitelist"
      cp -f "$file" "$BEPINEX_PLUGIN_CONFIG_DIR/AzuAntiCheat_Whitelist/"
    done
    echo "* Done!"
    echo "*"
  fi
  echo "*"
  echo "* Done checking AntiCheat"
  echo "*"
  echo "*********************************"
  echo ""
 
  echo ""
  echo "************************************************"
  echo "***** Setting up BepInEx env variables... ******"
  echo "************************************************"
  echo "*"
  export LD_PRELOAD="$APP_DIR/doorstop_libs/libdoorstop_x64.so"
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY=$BEPINEX_ROOT_DIR/core/BepInEx.Preloader.dll
  export LD_LIBRARY_PATH="$APP_DIR/doorstop_libs:$LD_LIBRARY_PATH"
  echo "* Done setting up variables!"
  echo "*"
  echo "************************************************"
  echo ""
fi # install plugins

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
  

