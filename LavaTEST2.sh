#!/bin/bash

function install() {
function printDelimiter {
  echo "==========================================="
}

function printGreen {
  echo -e "\e[1m\e[32m${1}\e[0m"
}

source <(curl -s https://raw.githubusercontent.com/CPITMschool/Scripts/main/logo.sh)

printGreen "Enter node moniker:"
read -r NODE_MONIKER

CHAIN_ID=lava-testnet-2
echo "export CHAIN_ID=${CHAIN_ID}" >> $HOME/.profile
source $HOME/.profile

source <(curl -s https://raw.githubusercontent.com/CPITMschool/Scripts/main/Nibiru/Dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1

sudo apt update # In case of permissions error, try running with sudo
sudo apt install -y unzip logrotate git jq sed wget curl coreutils systemd

git clone https://github.com/lavanet/lava-config.git
cd lava-config/testnet-2
# Read the configuration from the file
# Note: you can take a look at the config file and verify configurations
source setup_config/setup_config.sh
echo "Lava config file path: $lava_config_folder"
mkdir -p $lavad_home_folder
mkdir -p $lava_config_folder
cp default_lavad_config_files/* $lava_config_folder
# Copy the genesis.json file to the Lava config folder
# Set and create the lavad binary path
lavad_binary_path="$HOME/go/bin/"
mkdir -p $lavad_binary_path
# Download the genesis binary to the lava path
wget https://lava-binary-upgrades.s3.amazonaws.com/testnet-2/genesis/lavad
chmod +x lavad
# Lavad should now be accessible from PATH, to verify, try running
cp lavad /usr/local/bin
# In case it is not accessible, make sure $lavad_binary_path is part of PATH (you can refer to the "Go installation" section)

  sleep 1
  lavad config keyring-backend test
  lavad config chain-id $CHAIN_ID
  lavad init "$NODE_MONIKER" --chain-id $CHAIN_ID

sleep 10

sudo tee /etc/systemd/system/lavad.service > /dev/null << EOF
[Unit]
Description=Lava Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which lavad) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

printGreen "Завантажуємо снепшот для прискорення синхронізації ноди..." && sleep 1

SNAP_NAME=$(curl -s https://snapshots1-testnet.nodejumper.io/lava-testnet/info.json | jq -r .fileName)
curl "https://snapshots1-testnet.nodejumper.io/lava-testnet/${SNAP_NAME}" | lz4 -dc - | tar -xf - -C "$HOME/.lava"

seeds="3a445bfdbe2d0c8ee82461633aa3af31bc2b4dc0@testnet2-seed-node.lavanet.xyz:26656,e593c7a9ca61f5616119d6beb5bd8ef5dd28d62d@testnet2-seed-node2.lavanet.xyz:26656"

sudo systemctl daemon-reload
sudo systemctl enable lavad
sudo systemctl start lavad && sleep 5

# Change Port
sed -i 's/^proxy_app = "tcp:\/\/127.0.0.1:26658"*$/proxy_app = "tcp:\/\/127.0.0.1:30658"/' $HOME/.lava/config/config.toml
sed -i 's/^laddr = "tcp:\/\/127.0.0.1:26657"*$/laddr = "tcp:\/\/127.0.0.1:30657"/' $HOME/.lava/config/config.toml
sed -i 's/^pprof_laddr = "localhost:6060"*$/pprof_laddr = "localhost:6460"/' $HOME/.lava/config/config.toml
sed -i 's/^laddr = "tcp:\/\/0.0.0.0:26656"*$/laddr = "tcp:\/\/0.0.0.0:30656"/' $HOME/.lava/config/config.toml
external_address=$(wget -qO- eth0.me)
sed -i "s/^external_address =.*$/external_address = \"$external_address:30656\"/" $HOME/.lava/config/config.toml
sed -i 's/^prometheus_listen_addr = ":26660"*$/prometheus_listen_addr = ":30660"/' $HOME/.lava/config/config.toml


sed -i 's/^address = "tcp:\/\/0.0.0.0:1317"*$/address = "tcp:\/\/0.0.0.0:1717"/' $HOME/.lava/config/app.toml
sed -i 's/^address = ":8080"*$/address = ":8070"/' $HOME/.lava/config/app.toml
sed -i 's/^address = "0.0.0.0:9090"*$/address = "0.0.0.0:9490"/' $HOME/.lava/config/app.toml
sed -i 's/^address = "0.0.0.0:9091"*$/address = "0.0.0.0:9491"/' $HOME/.lava/config/app.toml

sed -i 's/^node = "tcp:\/\/localhost:26657"*$/node = "tcp:\/\/localhost:30657"/' $HOME/.lava/config/client.toml

sed -i \
    -e 's/timeout_commit = ".*"/timeout_commit = "30s"/g' \
    -e 's/timeout_propose = ".*"/timeout_propose = "1s"/g' \
    -e 's/timeout_precommit = ".*"/timeout_precommit = "1s"/g' \
    -e 's/timeout_precommit_delta = ".*"/timeout_precommit_delta = "500ms"/g' \
    -e 's/timeout_prevote = ".*"/timeout_prevote = "1s"/g' \
    -e 's/timeout_prevote_delta = ".*"/timeout_prevote_delta = "500ms"/g' \
    -e 's/timeout_propose_delta = ".*"/timeout_propose_delta = "500ms"/g' \
    -e 's/skip_timeout_commit = ".*"/skip_timeout_commit = false/g' \
    $HOME/.lava/config/client.toml

    systemctl restart lavad && sleep 5 
    journalctl -u lavad -f -o cat
    
printDelimiter
printGreen "Check logs:            sudo journalctl -u lavad -f -o cat"
printGreen "Check synchronization: lavad status 2>&1 | jq .SyncInfo.catching_up"
printDelimiter

}
install
