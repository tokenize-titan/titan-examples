#!/bin/sh
set -e

# read flags
for ARGUMENT in "$@"
do
	KEY=$(echo $ARGUMENT | cut -f1 -d=)

	KEY_LENGTH=${#KEY}
	VALUE="${ARGUMENT:$KEY_LENGTH+1}"

	export "$KEY"="$VALUE"
done

# check skip build flag
if [ -z "$SKIP_BUILD" ]
then
	docker build -f ../../../Dockerfile ../../../ -t titand:latest
  echo 'build done.'
else 
  echo 'build skipped.'
fi

echo now deploying...

# take down running project if needed
docker compose -f docker-compose.yml down >/dev/null 2>&1

# clean up old volume
rm -rf nodes

### On alice's machine
# initialize chain
docker run --rm -it -v ./nodes/alice:/root/.titan titand:latest init node-alice --chain-id titan-1 --default-denom tkx >/dev/null
# create keyring's passphrase
echo -n password > ./nodes/alice/passphrase.txt
# create account
echo $(cat ./nodes/alice/passphrase.txt)$'\n'$(cat ./nodes/alice/passphrase.txt) | \
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest keys add alice --keyring-backend file --keyring-dir /root/.titan/keys --output json > ./nodes/alice/alice_plain.info

### On bob's machine
docker run --rm -it -v ./nodes/bob:/root/.titan titand:latest init node-bob --chain-id titan-1 --default-denom tkx >/dev/null
# create keyring's passphrase
echo -n password > ./nodes/bob/passphrase.txt
# create account
echo $(cat ./nodes/bob/passphrase.txt)$'\n'$(cat ./nodes/bob/passphrase.txt) | \
docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest keys add bob --keyring-backend file --keyring-dir /root/.titan/keys --output json > ./nodes/bob/bob_plain.info

### On carol's machine
# initialize chain
docker run --rm -it -v ./nodes/carol:/root/.titan titand:latest init node-carol --chain-id titan-1 --default-denom tkx >/dev/null

### On alice's machine
# add alice as genesis account with tkx balance
cat ./nodes/alice/passphrase.txt | \
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest keys show alice --address --keyring-backend file --keyring-dir /root/.titan/keys | \
xargs -I {} docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest add-genesis-account "{}" 10000tkx
# alice stakes tkx 
echo $(cat ./nodes/alice/passphrase.txt)$'\n'$(cat ./nodes/alice/passphrase.txt) | \
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest gentx alice 1000tkx --keyring-backend file --keyring-dir /root/.titan/keys --chain-id titan-1 >/dev/null 2>&1

# alice passes genesis.json to bob
cp ./nodes/alice/config/genesis.json ./nodes/bob/config/genesis.json

### On bob's machine
# add bob as genesis account with tkx balance
cat ./nodes/bob/passphrase.txt | \
docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest keys show bob --address --keyring-backend file --keyring-dir /root/.titan/keys | \
xargs -I {} docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest add-genesis-account "{}" 5000tkx
# bob stakes tkx
echo $(cat ./nodes/bob/passphrase.txt)$'\n'$(cat ./nodes/bob/passphrase.txt) | \
docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest gentx bob 1000tkx --keyring-backend file --keyring-dir /root/.titan/keys --chain-id titan-1 >/dev/null 2>&1

# bob sends his generated txs back to alice
cp ./nodes/bob/config/gentx/gentx-* ./nodes/alice/config/gentx
# bob sends back the final genesis file to alice
cp ./nodes/bob/config/genesis.json ./nodes/alice/config/genesis.json

### On alice's machine
# alice collect all generated transactions into genesis file
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest validate-genesis >/dev/null

# alice distributes genesis file to stakeholders
cp ./nodes/alice/config/genesis.json ./nodes/bob/config/genesis.json
cp ./nodes/alice/config/genesis.json ./nodes/carol/config/genesis.json

### Sentries
# initialize alice's node
docker run --rm -it -v ./nodes/alice-sentry:/root/.titan titand:latest init node-alice-sentry --chain-id titan-1 --default-denom tkx >/dev/null
# initialize bob's node
docker run --rm -it -v ./nodes/bob-sentry:/root/.titan titand:latest init node-bob-sentry --chain-id titan-1 --default-denom tkx >/dev/null

### On alice's sentry node
# copy the genesis file
cp ./nodes/alice/config/genesis.json ./nodes/alice-sentry/config/genesis.json
# add alice's validator node as persistent peers
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@validator-alice:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/alice-sentry/config/config.toml
# config private peer ids
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} sed -i '' 's/private_peer_ids = ".*/private_peer_ids = "{}"/' ./nodes/alice-sentry/config/config.toml
# add bob's sentry node and carol node as seed peers
(docker run --rm -i -v ./nodes/bob-sentry:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-bob:26656; docker run --rm -i -v ./nodes/carol:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@node-carol:26656) | xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = ".*/seeds = "{}"/' ./nodes/alice-sentry/config/config.toml

### On alice's machine
# expose the port so that alice's sentry node can reach
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ./nodes/alice/config/config.toml
# add alice's sentry node as persistent peers
docker run --rm -i -v ./nodes/alice-sentry:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-alice:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/alice/config/config.toml

### On bob's sentry node
# copy the genesis file
cp ./nodes/bob/config/genesis.json ./nodes/bob-sentry/config/genesis.json
# add bob's validator node as persistent peers
docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@validator-bob:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/bob-sentry/config/config.toml
# config private peer ids
docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} sed -i '' 's/private_peer_ids = ".*/private_peer_ids = "{}"/' ./nodes/bob-sentry/config/config.toml
# add alice's sentry node and carol node as seed peers
(docker run --rm -i -v ./nodes/alice-sentry:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-alice:26656; docker run --rm -i -v ./nodes/carol:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@node-carol:26656) | xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = ".*/seeds = "{}"/' ./nodes/bob-sentry/config/config.toml

### On bob's machine
# expose the port so that bob's sentry node can reach
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ./nodes/bob/config/config.toml
# add bob's sentry node as persistent peers
docker run --rm -i -v ./nodes/bob-sentry:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-bob:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/bob/config/config.toml

### On carol's machine
# carol configures to add alice's and bob's sentry nodes as seed peers
(docker run --rm -i -v ./nodes/alice-sentry:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-alice:26656; docker run --rm -i -v ./nodes/bob-sentry:/root/.titan titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-bob:26656) | xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = ".*/seeds = "{}"/' ./nodes/carol/config/config.toml
# carol exposes his backend, makes it accessible/usable from outside world
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ./nodes/carol/config/config.toml

docker compose -f docker-compose.yml up -d
