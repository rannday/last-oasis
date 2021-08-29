#!/bin/bash

################################################################################
source ./conf.env
################################################################################
GAME_DIR="$HOME/game"                    # Game files
APP_ID=920720                            # Steam APP ID
SYSTEMD_DIR="$HOME/.config/systemd/user" # Systemd user directory
################################################################################
# Input checking
re='^[0-9]+$'
# Check input is number
if ! [[ $1 =~ $re ]] ; then
  echo "ERROR: Enter a number" >&2; exit 1
fi
# Check number is less than 16
if [ $1 -gt 15 ]; then
  echo "ERROR: Enter a number less than 16" >&2; exit 1
fi
# Check number is greater than 0
if [ $1 -lt 1 ]; then
  echo "ERROR; enter a number greater than 0" >&2; exit 1
fi
TOTAL=$1

################################################################################
# Create the game directory folder
if [ ! -d "$GAME_DIR" ]; then
  echo "Making game folder directory"
  mkdir $GAME_DIR
fi

################################################################################
# Check if file exist, if not, install game
steam_id="${GAME_DIR}/Mist/Binaries/Linux/steam_appid.txt"
echo $steam_id
if [ ! -f "$steam_id" ]; then
  /usr/games/steamcmd +login anonymous +force_install_dir $GAME_DIR +app_update $APP_ID validate +exit

  touch $steam_id
  echo "920720" > $steam_id
fi

################################################################################
# Build start script
function build_start {

  start_s="${GAME_DIR}/start$1.sh"
  touch $start_s

  echo "#!/bin/sh" > $start_s
  echo "" >> $start_s
  echo "export TERM=roxterm" >> $start_s
  echo "export templdpath=\$LD_LIBRARY_PATH" >> $start_s
  echo "export LD_LIBRARY_PATH=./linux64:\$LD_LIBRARY_PATH" >> $start_s
  echo "export SteamAppId=$APP_ID" >> $start_s
  echo "" >> $start_s
  echo "/usr/bin/sh ${GAME_DIR}/MistServer.sh -log -force_steamclient_link -messaging -NoLiveServer -EnableCheats -backendapiurloverride=\"backend.last-oasis.com\" -identifier=$IDENT$1 -port=$2 -CustomerKey=$CUST_KEY -ProviderKey=$PROV_KEY -slots=$SLOTS -QueryPort=$3 -OverrideConnectionAddress=$IP" >> $start_s
  echo "" >> $start_s
  echo "export LD_LIBRARY_PATH=\$templdpath" >> $start_s

  # Make executable
  chmod +x $start_s
}

################################################################################
# Build update script
function build_update {

  update_s="$GAME_DIR/update.sh"
  touch $update_s

  echo "#!/bin/sh" > $update_s
  echo "" >> $update_s
  echo "/usr/games/steamcmd +login anonymous +force_install_dir $GAME_DIR +app_update $APP_ID validate +exit" >> $update_s

  # Make executable
  chmod +x $update_s
}

################################################################################
# Build tmux master service
function build_tmux {

  tmux_s="$SYSTEMD_DIR/master.service"
  touch $tmux_s

  echo "[Unit]" > $tmux_s
  echo "Description=Master tmux service" >> $tmux_s
  echo "After=network-online.target" >> $tmux_s
  echo "Wants=network-online.target" >> $tmux_s
  echo "" >> $tmux_s
  echo "[Service]" >> $tmux_s
  echo "Type=forking" >> $tmux_s
  echo "ExecStart=/usr/bin/tmux new-session -s master -d" >> $tmux_s
  echo "ExecStop=/usr/bin/tmux kill-session -t master" >> $tmux_s
  echo "" >> $tmux_s
  echo "[Install]" >> $tmux_s
  echo "WantedBy=multi-user.target" >> $tmux_s
}

################################################################################
# Build target service
function build_target {

  target_s="$SYSTEMD_DIR/oasis.target"
  touch $target_s

  requires="Requires="
  for i in $(seq 1 $TOTAL)
  do
    requires="${requires}oasis@${i}.service "
  done

  echo "[Unit]" > $target_s
  echo "Description=\"Last Oasis Worker\"" >> $target_s
  echo "$requires" >> $target_s
  echo "" >> $target_s
  echo "[Install]" >> $target_s
  echo "WantedBy=multi-user.target" >> $target_s
}

################################################################################
# Build main service template
function build_service {

  service_s="$SYSTEMD_DIR/oasis@.service"
  touch $service_s

  echo "[Unit]" > $service_s
  echo "Description="Last Oasis Server #%i" >> $service_s
  echo "PartOf=oasis.target" >> $service_s
  echo "After=master.service" >> $service_s
  echo "" >> $service_s
  echo "[Service]" >> $service_s
  echo "Type=oneshot" >> $service_s
  echo "RemainAfterExit=yes" >> $service_s
  echo "WorkingDirectory=/home/oasis/game" >> $service_s
  echo "ExecStart=/usr/bin/tmux new-session -s oasis%i -d \"/usr/bin/sh /home/oasis/game/start%i.sh; exec \$SHELL\"" >> $service_s
  echo "ExecStop=/usr/bin/tmux kill-session -t oasis%i" >> $service_s
  echo "ExecReload=/bin/kill -s HUP" >> $service_s
  echo "KillSignal=SIGINT" >> $service_s
  echo "LimitNOFILE=100000" >> $service_s
  echo "" >> $service_s
  echo "[Install]" >> $service_s
  echo "WantedBy=multi-user.target" >> $service_s
}

################################################################################
# Build scripts
echo "Creating start scripts"
for i in $(seq 1 $TOTAL)
do
  build_start $i $PORTS1 $PORTS2
  PORTS1=$((PORTS1 + 1))
  PORTS2=$((PORTS2 + 1))
done
echo "Creating update scripts"
build_update

################################################################################
# Check services
echo "Checking tmux master server status"
tmux_service="$(systemctl --user is-active master.service)"
if [ "${tmux_service}" = "active" ]; then
  systemctl --user stop master.service
  systemctl --user disable master.service
fi
echo "Checking oasis target status"
oasis_target="$(systemctl --user is-active oasis.target)"
if [ "${oasis_target}" = "active" ]; then
  systemctl --user stop oasis.target
  systemctl --user disable oasis.target
fi

echo "Reloading"
systemctl --user daemon-reload

if [ ! -d "$SYSTEMD_DIR" ]; then
  echo "Creating systemd user directory"
  mkdir -p $SYSTEMD_DIR
fi

################################################################################
# Build services
echo "Creating tmux service"
build_tmux
echo "Creating target service"
build_target
echo "Creating service"
build_service

echo "Reloading"
systemctl --user daemon-reload

################################################################################
# Start everything
echo "Starting tmux master server"
#systemctl --user enable --now master.service
systemctl --user start master.service
systemctl --user enable master.service
systemctl --user status master.service

echo "Starting oasis target service"
systemctl --user start oasis.target
systemctl --user enable oasis.target
systemctl --user status oasis.target

# END