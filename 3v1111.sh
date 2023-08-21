#!/bin/bash

function install() {
function printDelimiter {
  echo "==========================================="
}

function printGreen {
  echo -e "\e[1m\e[32m${1}\e[0m"
}

source <(curl -s https://raw.githubusercontent.com/CPITMschool/Scripts/main/logo.sh)

source <(curl -s https://raw.githubusercontent.com/CPITMschool/Scripts/main/Nibiru/Ports.sh) && sleep 3
export -f selectPortSet && selectPortSet

read -r -p "Введіть ім'я для moniker ноди: " NODE_MONIKER

CHAIN_ID=lava-testnet-2
echo "export CHAIN_ID=${CHAIN_ID}" >> $HOME/.profile
source $HOME/.profile

source <(curl -s https://raw.githubusercontent.com/CPITMschool/Scripts/main/Nibiru/Dependencies.sh)

echo "" && printGreen "Встановлюємо Go..." && sleep 1

cd || return
rm -rf lava
git clone https://github.com/lavanet/lava
cd lava || return
git checkout v0.21.1.2
make install

sleep 1
lavad config keyring-backend test
lavad config chain-id $CHAIN_ID
lavad init "$NODE_MONIKER" --chain-id $CHAIN_ID

wget -O genesis.json https://snapshots.polkachu.com/testnet-genesis/lava/genesis.json --inet4-only
mv genesis.json ~/.lava/config

sed -i 's/seeds = ""/seeds = "ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@testnet-seeds.polkachu.com:19956"/' ~/.lava/config/config.toml

printGreen "Starting service and synchronization..." && sleep 1

sleep 10

sudo cp $HOME/.lava/data/priv_validator_state.json $HOME/.lava/priv_validator_state.json.backup && sleep 10
sudo rm -rf $HOME/.lava/data
curl -L https://snapshots.kjnodes.com/lava-testnet/snapshot_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.lava && sleep 10
sudo mv $HOME/.lava/priv_validator_state.json.backup $HOME/.lava/data/priv_validator_state.json

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

sudo systemctl daemon-reload
sudo systemctl enable lavad
sudo systemctl start lavad

printDelimiter
printGreen "Check logs:            sudo journalctl -u lavad -f -o cat"
printGreen "Check synchronization: lavad status 2>&1 | jq .SyncInfo.catching_up"
printDelimiter

}
install
