#!/bin/bash

source $PWD/conf.env

systemctl --user stop oasis.target
systemctl --user stop master.target
systemctl --user disable oasis.target
systemctl --user disable master.target

tmux kill-session -t master

rm -rf $GAME_DIR $HOME/.config $HOME/.steam
systemctl --user daemon-reload