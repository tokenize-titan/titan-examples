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

if [ -z "$SKIP_KMS_BUILD" ]
then
	docker build --build-arg TMKMS_VERSION=v0.12.2 -f ./Dockerfile.tmkms . -t tmkms:v0.12.2
  echo 'build tendermint kms done.'
else 
  echo 'build tendermint kms skipped.'
fi

echo now deploying...

# take down running project if needed
docker compose -f docker-compose.yml down >/dev/null 2>&1

# clean up old volume
rm -rf nodes

### On alice's machine
# initialize chain
docker run --rm -it -v ./nodes/alice:/root/.titand titand:latest init node-alice --chain-id titan_18889-1  >/dev/null
# create keyring's passphrase
echo -n password > ./nodes/alice/passphrase.txt
# create account
echo $(cat ./nodes/alice/passphrase.txt)$'\n'$(cat ./nodes/alice/passphrase.txt) | \
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest keys add alice --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/alice/alice_plain.info
# expose private validator listening port
sed -i '' 's/priv_validator_laddr = ""/priv_validator_laddr = "tcp:\/\/0.0.0.0:26659"/g' ./nodes/alice/config/config.toml
# make sure it will no more look for the consensus key on file
sed -i '' 's/^priv_validator_key_file/# priv_validator_key_file/g' ./nodes/alice/config/config.toml
# make sure it will no more look for the consensus state file either
sed -i '' 's/^priv_validator_state_file/# priv_validator_state_file/g' ./nodes/alice/config/config.toml

### On bob's machine
docker run --rm -it -v ./nodes/bob:/root/.titand titand:latest init node-bob --chain-id titan_18889-1  >/dev/null
# create keyring's passphrase
echo -n password > ./nodes/bob/passphrase.txt
# create account
echo $(cat ./nodes/bob/passphrase.txt)$'\n'$(cat ./nodes/bob/passphrase.txt) | \
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest keys add bob --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/bob/bob_plain.info

### On carol's machine
# initialize chain
docker run --rm -it -v ./nodes/carol:/root/.titand titand:latest init node-carol --chain-id titan_18889-1  >/dev/null

### On alice's machine
# add alice as genesis account with titan balance
cat ./nodes/alice/passphrase.txt | \
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest keys show alice --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest add-genesis-account "{}" 10000tkx
# alice stakes titan 
echo $(cat ./nodes/alice/passphrase.txt)$'\n'$(cat ./nodes/alice/passphrase.txt) | \
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest gentx alice 1000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18889-1 >/dev/null 2>&1

# alice passes genesis.json to bob
cp ./nodes/alice/config/genesis.json ./nodes/bob/config/genesis.json

### On bob's machine
# add bob as genesis account with titan balance
cat ./nodes/bob/passphrase.txt | \
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest keys show bob --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest add-genesis-account "{}" 5000tkx
# bob stakes titan
echo $(cat ./nodes/bob/passphrase.txt)$'\n'$(cat ./nodes/bob/passphrase.txt) | \
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest gentx bob 1000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18889-1 >/dev/null 2>&1

# bob sends his generated txs back to alice
cp ./nodes/bob/config/gentx/gentx-* ./nodes/alice/config/gentx
# bob sends back the final genesis file to alice
cp ./nodes/bob/config/genesis.json ./nodes/alice/config/genesis.json

### On alice's machine
# alice collect all generated transactions into genesis file
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest validate-genesis >/dev/null

# alice distributes genesis file to stakeholders
cp ./nodes/alice/config/genesis.json ./nodes/bob/config/genesis.json
cp ./nodes/alice/config/genesis.json ./nodes/carol/config/genesis.json


### On alice's KMS machine
# initialize
docker run --rm -it -v ./nodes/alice-kms:/root/tmkms tmkms:v0.12.2 init /root/tmkms >/dev/null
# set the proper protocol version
sed -i '' 's/^protocol_version = .*$/protocol_version = "v0.34"/g' ./nodes/alice-kms/tmkms.toml
# set the key file name
sed -i '' 's/path = "\/root\/tmkms\/secrets\/cosmoshub-3-consensus.key"/path = "\/root\/tmkms\/secrets\/alice-consensus.key"/g' ./nodes/alice-kms/tmkms.toml
# replace chain id
sed -i '' 's/cosmoshub-3/titan_18889-1/g' ./nodes/alice-kms/tmkms.toml
# generate consensus public key
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest tendermint show-validator \
| tr -d '\n' | tr -d '\r' > ./nodes/alice/config/pub_validator_key.json
# move private consensus key out of validator node, to kms
mv ./nodes/alice/config/priv_validator_key.json ./nodes/alice-kms/secrets/priv_validator_key.json
# import softsign
docker run --rm -it -v ./nodes/alice-kms:/root/tmkms -w /root/tmkms tmkms:v0.12.2 softsign import secrets/priv_validator_key.json secrets/alice-consensus.key >/dev/null
# set up kms connection
sed -i '' 's/^addr = "tcp:.*$/addr = "tcp:\/\/validator-alice:26659"/g' ./nodes/alice-kms/tmkms.toml

### Sentries
# initialize alice's node
docker run --rm -it -v ./nodes/alice-sentry:/root/.titand titand:latest init node-alice-sentry --chain-id titan_18889-1  >/dev/null
# initialize bob's node
docker run --rm -it -v ./nodes/bob-sentry:/root/.titand titand:latest init node-bob-sentry --chain-id titan_18889-1  >/dev/null

### On alice's sentry node
# copy the genesis file
cp ./nodes/alice/config/genesis.json ./nodes/alice-sentry/config/genesis.json
# add alice's validator node as persistent peers
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@validator-alice:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/alice-sentry/config/config.toml
# config private peer ids
docker run --rm -i -v ./nodes/alice:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} sed -i '' 's/private_peer_ids = ".*/private_peer_ids = "{}"/' ./nodes/alice-sentry/config/config.toml
# add bob's sentry node and carol node as seed peers
(docker run --rm -i -v ./nodes/bob-sentry:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-bob:26656; docker run --rm -i -v ./nodes/carol:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@node-carol:26656) | xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = ".*/seeds = "{}"/' ./nodes/alice-sentry/config/config.toml

### On alice's machine
# expose the port so that alice's sentry node can reach
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ./nodes/alice/config/config.toml
# add alice's sentry node as persistent peers
docker run --rm -i -v ./nodes/alice-sentry:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-alice:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/alice/config/config.toml

### On bob's sentry node
# copy the genesis file
cp ./nodes/bob/config/genesis.json ./nodes/bob-sentry/config/genesis.json
# add bob's validator node as persistent peers
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@validator-bob:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/bob-sentry/config/config.toml
# config private peer ids
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} sed -i '' 's/private_peer_ids = ".*/private_peer_ids = "{}"/' ./nodes/bob-sentry/config/config.toml
# add alice's sentry node and carol node as seed peers
(docker run --rm -i -v ./nodes/alice-sentry:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-alice:26656; docker run --rm -i -v ./nodes/carol:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@node-carol:26656) | xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = ".*/seeds = "{}"/' ./nodes/bob-sentry/config/config.toml

### On bob's machine
# expose the port so that bob's sentry node can reach
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ./nodes/bob/config/config.toml
# add bob's sentry node as persistent peers
docker run --rm -i -v ./nodes/bob-sentry:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-bob:26656 | xargs -I{} sed -i '' 's/persistent_peers = ".*/persistent_peers = "{}"/' ./nodes/bob/config/config.toml

### On carol's machine
# carol configures to add alice's and bob's sentry nodes as seed peers
(docker run --rm -i -v ./nodes/alice-sentry:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-alice:26656; docker run --rm -i -v ./nodes/bob-sentry:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@sentry-bob:26656) | xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = ".*/seeds = "{}"/' ./nodes/carol/config/config.toml
# carol exposes his backend, makes it accessible/usable from outside world
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ./nodes/carol/config/config.toml

docker compose -f docker-compose.yml up -d
