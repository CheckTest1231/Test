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

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID=lava-testnet-1
echo "export CHAIN_ID=${CHAIN_ID}" >> $HOME/.profile
source $HOME/.profile

source <(curl -s https://raw.githubusercontent.com/CPITMschool/Scripts/main/Nibiru/Dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1

cd $HOME || return
rm -rf lava
git clone https://github.com/lavanet/lava
cd lava
latestTag=$(curl -s https://api.github.com/repos/lavanet/lava/releases/latest | grep '.tag_name'|cut -d\" -f4)
echo $latestTag
git checkout $latestTag
make install && sleep 3
cd ~

sleep 1
lavad config keyring-backend os
lavad config chain-id $CHAIN_ID
lavad init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -Ls https://services.bccnodes.com/testnets/lava/genesis.json > $HOME/.lava/config/genesis.json

 peers=""
  sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.lava/config/config.toml
  seeds="3a445bfdbe2d0c8ee82461633aa3af31bc2b4dc0@testnet2-seed-node.lavanet.xyz:26656,e593c7a9ca61f5616119d6beb5bd8ef5dd28d62d@testnet2-seed-node2.lavanet.xyz:26656"
  sed -i.bak -e "s/^seeds =.*/seeds = \"$seeds\"/" $HOME/.lava/config/config.toml

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

# Customize ports
CLIENT_TOML=$HOME/.lava/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

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