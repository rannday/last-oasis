#!/bin/bash

systemctl --user stop oasis.target
systemctl --user stop master.target
systemctl --user disable oasis.target
systemctl --user disable master.target

#rm -rf $HOME/game
#rm -rf $HOME/.steam
rm -rf $HOME/.config/systemd
systemctl --user daemon-reload