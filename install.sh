#!/bin/bash

TOTAL=1

function check_config {
  if [ ! -f "$PWD/conf.env" ]; then
    echo "ERROR: Missing configuration file"
    exit 1
  fi
  source ./conf.env
}

function check_input {
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]] ; then
    echo "ERROR: Enter a number" >&2; exit 1
  fi
  if [ $1 -gt 15 ]; then
    echo "ERROR: Enter a number less than 16" >&2; exit 1
  fi
  if [ $1 -lt 1 ]; then
    echo "ERROR; enter a number greater than 0" >&2; exit 1
  fi
  TOTAL=$1
}

function create_dirs {
  mkdir -p $GAME_DIR
  mkdir -p $UNIT_DIR
}

function check_services {
  systemctl --user stop master.service
  systemctl --user disable master.service
  systemctl --user stop oasis.target
  systemctl --user disable oasis.target
}

function install_game {
  steam_id="${GAME_DIR}/Mist/Binaries/Linux/steam_appid.txt"
  if [ ! -f "$steam_id" ]; then
    /usr/games/steamcmd +login anonymous +force_install_dir $GAME_DIR +app_update $APP_ID_SRV validate +exit
    echo "920720" > $steam_id
  fi
}

function build_start {
  start_s="${GAME_DIR}/start$1.sh"
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

  chmod +x $start_s
}

function build_update {
  update_s="$GAME_DIR/update.sh"
  echo "#!/bin/sh" > $update_s
  echo "" >> $update_s
  echo "/usr/games/steamcmd +login anonymous +force_install_dir $GAME_DIR +app_update $APP_ID_SRV validate +exit" >> $update_s
  chmod +x $update_s
}

function build_tmux {
  tmux_s="$UNIT_DIR/master.service"
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
  echo "WantedBy=default.target" >> $tmux_s
  systemctl --user daemon-reload
}

function build_target {
  target_s="$UNIT_DIR/oasis.target"
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
  echo "WantedBy=default.target" >> $target_s
  systemctl --user daemon-reload
}

function build_service {
  service_s="$UNIT_DIR/oasis@.service"
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
  echo "WantedBy=default.target" >> $service_s
  systemctl --user daemon-reload
}

function start_services {
  systemctl --user start master.service
  systemctl --user enable master.service
  systemctl --user status master.service
  systemctl --user start oasis.target
  systemctl --user enable oasis.target
  systemctl --user status oasis.target
}

check_config
check_input $1
create_dirs
check_services
install_game
for i in $(seq 1 $TOTAL)
do
  build_start $i $PORTS1 $PORTS2
  PORTS1=$((PORTS1 + 1))
  PORTS2=$((PORTS2 + 1))
done
build_update
build_tmux
build_target
build_service
start_services

echo "Done! exiting"
exit 0
