# Last Oasis Server Install Script
## Creates 1-15 servers

## Ubuntu 20.04

## Install prerequisites
`sudo apt install git tmux`

## Create an unprivileged user
`sudo adduser oasis`

## Install steamcmd
```
sudo apt update && sudo apt upgrade -y
sudo add-apt-repository -y multiverse
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steamcmd -y
```

## Switch to user
`su oasis`

## Clone repo
`cd`  
`git clone https://github.com/rannday/last-oasis.git`

## Edit conf.env to your needs
`nano last-oasis/conf.env`

## Create app
`sudo nano /etc/ufw/applications.d/last-oasis`

```
[LastOasis]
title=Last Oasis
description=game
ports=5555:5565/udp|27015:27025/udp
```

`sudo ufw app update LastOasis`
`sudo ufw allow LastOasis`