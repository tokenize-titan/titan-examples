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
docker run --rm -it -v $(pwd)/nodes/val1:/root/.titand titand:latest init val1 --chain-id titan_18887-1  >/dev/null
# create keyring's passphrase
printf password > ./nodes/val1/passphrase.txt
# create account
echo $(cat ./nodes/val1/passphrase.txt)$'\n'$(cat ./nodes/val1/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest keys add val1 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val1/val1.info

### On val2's machine
docker run --rm -it -v $(pwd)/nodes/val2:/root/.titand titand:latest init val2 --chain-id titan_18887-1  >/dev/null
# create keyring's passphrase
printf password > ./nodes/val2/passphrase.txt
# create account
echo $(cat ./nodes/val2/passphrase.txt)$'\n'$(cat ./nodes/val2/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest keys add val2 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val2/val2.info

### On val3's machine
docker run --rm -it -v $(pwd)/nodes/val3:/root/.titand titand:latest init val3 --chain-id titan_18887-1  >/dev/null
# create keyring's passphrase
printf password > ./nodes/val3/passphrase.txt
# create account
echo $(cat ./nodes/val3/passphrase.txt)$'\n'$(cat ./nodes/val3/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest keys add val3 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val3/val3.info

### On val4's machine
docker run --rm -it -v $(pwd)/nodes/val4:/root/.titand titand:latest init val4 --chain-id titan_18887-1  >/dev/null
# create keyring's passphrase
printf password > ./nodes/val4/passphrase.txt
# create account
echo $(cat ./nodes/val4/passphrase.txt)$'\n'$(cat ./nodes/val4/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest keys add val4 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val3/val3.info

### On explorer's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/explorer:/root/.titand titand:latest init explorer --chain-id titan_18887-1  >/dev/null

############################## GENESIS SETUP ##############################

echo 'setting up genesis...'

### On val1's machine
# add val1 as genesis account with titan balance
cat ./nodes/val1/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest keys show val1 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val1 stakes titan 
echo $(cat ./nodes/val1/passphrase.txt)$'\n'$(cat ./nodes/val1/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest gentx val1 1001000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18887-1 >/dev/null 2>&1

# val1 passes genesis.json to val2
cp ./nodes/val1/config/genesis.json ./nodes/val2/config/genesis.json

### On val2's machine
# add val2 as genesis account with titan balance
cat ./nodes/val2/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest keys show val2 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val2 stakes titan
echo $(cat ./nodes/val2/passphrase.txt)$'\n'$(cat ./nodes/val2/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest gentx val2 1000000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18887-1 >/dev/null 2>&1

# val2 sends his generated txs back to val1
cp ./nodes/val2/config/gentx/gentx-* ./nodes/val1/config/gentx

# val2 sends genesis file to val3
cp ./nodes/val2/config/genesis.json ./nodes/val3/config/genesis.json

### On val3's machine
# add val3 as genesis account with titan balance
cat ./nodes/val3/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest keys show val3 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val3 stakes titan
echo $(cat ./nodes/val3/passphrase.txt)$'\n'$(cat ./nodes/val3/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest gentx val3 500000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18887-1 >/dev/null 2>&1

# val3 sends his generated txs back to val1
cp ./nodes/val3/config/gentx/gentx-* ./nodes/val1/config/gentx

# val3 sends genesis file to val4
cp ./nodes/val3/config/genesis.json ./nodes/val4/config/genesis.json

### On val4's machine
# add val4 as genesis account with titan balance
cat ./nodes/val4/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest keys show val4 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val4 stakes titan
echo $(cat ./nodes/val4/passphrase.txt)$'\n'$(cat ./nodes/val4/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest gentx val4 500000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18887-1 >/dev/null 2>&1

# val4 sends his generated txs back to val1
cp ./nodes/val4/config/gentx/gentx-* ./nodes/val1/config/gentx

# val4 sends back the final genesis file to val1
cp ./nodes/val4/config/genesis.json ./nodes/val1/config/genesis.json

############################## GENESIS COMPLETE & DISTRIBUTE ##############################

echo 'genesis complete, distributing...'

### On val1's machine
# val1 collect all generated transactions into genesis file
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest validate-genesis >/dev/null

# val1 distributes genesis file to stakeholders
cp ./nodes/val1/config/genesis.json ./nodes/val2/config/genesis.json
cp ./nodes/val1/config/genesis.json ./nodes/val3/config/genesis.json
cp ./nodes/val1/config/genesis.json ./nodes/val4/config/genesis.json
cp ./nodes/val1/config/genesis.json ./nodes/explorer/config/genesis.json


############################## explorer SETUP ##############################

echo 'setting up explorer...'

# explorer exposes his backend, makes it accessible/usable from outside world
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ./nodes/explorer/config/config.toml

############################## CONNECTION SETUP ##############################

echo 'setting up connection...'

### On val1's machine
# val1 configures to add val2 as seed peers
(docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@val2:26656; \
docker run --rm -i -v $(pwd)/nodes/explorer:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@explorer:26656; \
)\
| xargs echo | sed 's/ /,/g' | xargs -I{} sed -i '' 's/seeds = \".*/seeds = "{}"/' ./nodes/val1/config/config.toml

### On val2's machine
# val2 configures to add val1 and explorer as seed peers
(docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@val1:26656; \
docker run --rm -i -v $(pwd)/nodes/explorer:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@explorer:26656 \
) \
| xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = \".*/seeds = "{}"/' ./nodes/val2/config/config.toml

### On val3's machine
# val3 configures to add val4 as seed peers
(docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@val4:26656; \
)\
| xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = \".*/seeds = "{}"/' ./nodes/val3/config/config.toml

### On val4's machine
# val4 configures to add val3 as seed peers
(docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@val3:26656; \
)\
| xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = \".*/seeds = "{}"/' ./nodes/val4/config/config.toml

### On explorer's machine
# explorer configures to add val1, val2 as seed peers
(docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@val1:26656; \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest tendermint show-node-id | \
xargs -I{} echo {}@val2:26656) \
| xargs echo | sed 's/ /,/' | xargs -I{} sed -i '' 's/seeds = \".*/seeds = "{}"/' ./nodes/explorer/config/config.toml

############################## NODES START ##############################

docker compose -f docker-compose.yml up -d val1 val2 val3 val4 explorer
