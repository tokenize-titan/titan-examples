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

############################## NODES SETUP ##############################

echo 'setting up nodes...'

### On val1's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/val1:/root/.titand titand:latest init val1 --chain-id titan_18889-1  >/dev/null
# create keyring's passphrase
printf password > ./nodes/val1/passphrase.txt
# create account
echo $(cat ./nodes/val1/passphrase.txt)$'\n'$(cat ./nodes/val1/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest keys add val1 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val1/val1.info

### On val2's machine
docker run --rm -it -v $(pwd)/nodes/val2:/root/.titand titand:latest init val2 --chain-id titan_18889-1  >/dev/null
# create keyring's passphrase
printf password > ./nodes/val2/passphrase.txt
# create account
echo $(cat ./nodes/val2/passphrase.txt)$'\n'$(cat ./nodes/val2/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest keys add val2 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val2/val2.info

### On explorer's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/explorer:/root/.titand titand:latest init explorer --chain-id titan_18889-1  >/dev/null

############################## GENESIS SETUP ##############################

echo 'setting up genesis...'

### On val1's machine
# Change genesis setting
jq '.app_state.staking.params.max_validators = 1' ./nodes/val1/config/genesis.json > ./nodes/val1/config/tmp.json && mv ./nodes/val1/config/tmp.json ./nodes/val1/config/genesis.json

# add val1 as genesis account with titan balance
cat ./nodes/val1/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest keys show val1 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val1 stakes titan 
echo $(cat ./nodes/val1/passphrase.txt)$'\n'$(cat ./nodes/val1/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest gentx val1 1000000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18889-1 >/dev/null 2>&1

# val1 passes genesis.json to val2
cp ./nodes/val1/config/genesis.json ./nodes/val2/config/genesis.json

### On val2's machine
# add val2 as genesis account with titan balance
cat ./nodes/val2/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest keys show val2 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val2 stakes titan
echo $(cat ./nodes/val2/passphrase.txt)$'\n'$(cat ./nodes/val2/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest gentx val2 1000000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18889-1 >/dev/null 2>&1

# val2 sends his generated txs back to val1
cp ./nodes/val2/config/gentx/gentx-* ./nodes/val1/config/gentx

# val2 sends genesis file to val1
cp ./nodes/val2/config/genesis.json ./nodes/val1/config/genesis.json

############################## GENESIS COMPLETE & DISTRIBUTE ##############################

echo 'genesis complete, distributing...'

### On val1's machine
# val1 collect all generated transactions into genesis file
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest validate-genesis >/dev/null

# val1 distributes genesis file to stakeholders
cp ./nodes/val1/config/genesis.json ./nodes/val2/config/genesis.json
cp ./nodes/val1/config/genesis.json ./nodes/explorer/config/genesis.json


############################## explorer SETUP ##############################

echo 'setting up explorer...'

# explorer exposes his backend, makes it accessible/usable from outside world
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ./nodes/explorer/config/config.toml

############################## CONNECTION SETUP ##############################

echo 'setting up connection...'



############################## NODES START ##############################

docker compose -f docker-compose.yml up -d val1 val2
