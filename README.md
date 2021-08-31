# Last Oasis Server Install Script
## Creates 1-15 servers

## Ubuntu 20.04

## Install prerequisites
```
sudo apt update && sudo apt upgrade -y
sudo add-apt-repository -y multiverse
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install lib32gcc1 steamcmd git tmux -y
```

## Create an unprivileged user
```
sudo adduser oasis
sudo loginctl enable-linger oasis
```

## Switch to user
`su oasis`

## Clone repo
`cd`  
`git clone https://github.com/rannday/last-oasis.git`

## Edit conf.env to your needs
`nano last-oasis/conf.env`

## Open firewall
### Change according to needs
```
sudo ufw allow 5555:5569/udp
sudo ufw allow 27015:27029/udp
```

## Install
```
./install.sh 1
./install.sh 5
./install.sh 15
```
