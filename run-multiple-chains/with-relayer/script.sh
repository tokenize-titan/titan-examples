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

#################################################################################################################################
################################################## Chain titan_18887-1 ##########################################################
#################################################################################################################################
echo 'Chain titan_18887-1'

############################## NODES SETUP ##############################

echo 'setting up nodes...'

### On val1's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/val1:/root/.titand titand:latest init val1 --chain-id titan_18887-1  >/dev/null
# config app.toml
sed -i '' '/^\[grpc\]$/,/^\[/ s/^\(address = \).*/\1\"0.0.0.0:9090\"/' $(pwd)/nodes/val1/config/app.toml
# config config.toml
sed -i '' '/^\[rpc\]$/,/^\[/ s/^\(laddr = \).*/\1\"tcp:\/\/0.0.0.0:26657\"/' $(pwd)/nodes/val1/config/config.toml
# create keyring's passphrase
printf password > ./nodes/val1/passphrase.txt
# create account
echo $(cat ./nodes/val1/passphrase.txt)$'\n'$(cat ./nodes/val1/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest keys add val1 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val1/val1.info

############################## GENESIS SETUP ##############################

echo 'setting up genesis...'

# Change genesis setting
jq '.app_state.evm.params.evm_denom = "atkx"' ./nodes/val1/config/genesis.json > ./nodes/val1/config/tmp.json && mv ./nodes/val1/config/tmp.json ./nodes/val1/config/genesis.json
# add val1 as genesis account with titan balance
cat ./nodes/val1/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest keys show val1 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest add-genesis-account "{}" 10000000tkx
# val1 stakes titan 
echo $(cat ./nodes/val1/passphrase.txt)$'\n'$(cat ./nodes/val1/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest gentx val1 1000tkx --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_18887-1 >/dev/null 2>&1
# add balance for rly1
jq -r '.address' ./hermes/rly1.json | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest add-genesis-account {} 10000000tkx

############################## GENESIS COMPLETE & DISTRIBUTE ##############################

echo 'genesis complete, distributing...'

### On val1's machine
# val1 collect all generated transactions into genesis file
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v $(pwd)/nodes/val1:/root/.titand titand:latest validate-genesis >/dev/null


#################################################################################################################################
################################################## Chain titan_90002-1 ##########################################################
#################################################################################################################################
echo 'Chain titan_90002-1'


############################## NODES SETUP ##############################

echo 'setting up nodes...'

### On val2's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/val2:/root/.titand titand:latest init val2 --chain-id titan_90002-1 --default-denom tkx2 >/dev/null
# config app.toml
sed -i '' '/^\[grpc\]$/,/^\[/ s/^\(address = \).*/\1\"0.0.0.0:9090\"/' $(pwd)/nodes/val2/config/app.toml
# config config.toml
sed -i '' '/^\[rpc\]$/,/^\[/ s/^\(laddr = \).*/\1\"tcp:\/\/0.0.0.0:26657\"/' $(pwd)/nodes/val2/config/config.toml
# create keyring's passphrase
printf password > ./nodes/val2/passphrase.txt
# create account
echo $(cat ./nodes/val2/passphrase.txt)$'\n'$(cat ./nodes/val2/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest keys add val2 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val2/val2.info

############################## GENESIS SETUP ##############################

echo 'setting up genesis...'

# Change genesis setting
jq '.app_state.evm.params.evm_denom = "tkx2"' ./nodes/val2/config/genesis.json > ./nodes/val2/config/tmp.json && mv ./nodes/val2/config/tmp.json ./nodes/val2/config/genesis.json
# add val2 as genesis account with titan balance
cat ./nodes/val2/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest keys show val2 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest add-genesis-account "{}" 100000000000000000000tkx2
# val2 stakes titan 
echo $(cat ./nodes/val2/passphrase.txt)$'\n'$(cat ./nodes/val2/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest gentx val2 1000000000000000000tkx2 --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_90002-1 >/dev/null 2>&1
# add balance for rly2
jq -r '.address' ./hermes/rly2.json | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest add-genesis-account {} 100000000000000000000tkx2

############################## GENESIS COMPLETE & DISTRIBUTE ##############################

echo 'genesis complete, distributing...'

### On val2's machine
# val2 collect all generated transactions into genesis file
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v $(pwd)/nodes/val2:/root/.titand titand:latest validate-genesis >/dev/null

#################################################################################################################################
################################################## Chain titan_90003-1 ##########################################################
#################################################################################################################################
echo 'Chain titan_90003-1'


############################## NODES SETUP ##############################

echo 'setting up nodes...'

### On val3's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/val3:/root/.titand titand:latest init val3 --chain-id titan_90003-1 --default-denom tkx3 >/dev/null
# config app.toml
sed -i '' '/^\[grpc\]$/,/^\[/ s/^\(address = \).*/\1\"0.0.0.0:9090\"/' $(pwd)/nodes/val3/config/app.toml
# config config.toml
sed -i '' '/^\[rpc\]$/,/^\[/ s/^\(laddr = \).*/\1\"tcp:\/\/0.0.0.0:26657\"/' $(pwd)/nodes/val3/config/config.toml
# create keyring's passphrase
printf password > ./nodes/val3/passphrase.txt
# create account
echo $(cat ./nodes/val3/passphrase.txt)$'\n'$(cat ./nodes/val3/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest keys add val3 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val3/val3.info

############################## GENESIS SETUP ##############################

echo 'setting up genesis...'

# Change genesis setting
jq '.app_state.evm.params.evm_denom = "tkx3"' ./nodes/val3/config/genesis.json > ./nodes/val3/config/tmp.json && mv ./nodes/val3/config/tmp.json ./nodes/val3/config/genesis.json
# add val3 as genesis account with titan balance
cat ./nodes/val3/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest keys show val3 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest add-genesis-account "{}" 100000000000000000000tkx3
# val3 stakes titan 
echo $(cat ./nodes/val3/passphrase.txt)$'\n'$(cat ./nodes/val3/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest gentx val3 1000000000000000000tkx3 --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_90003-1 >/dev/null 2>&1
# add balance for rly3
jq -r '.address' ./hermes/rly3.json | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest add-genesis-account {} 100000000000000000000tkx3

############################## GENESIS COMPLETE & DISTRIBUTE ##############################

echo 'genesis complete, distributing...'

### On val3's machine
# val3 collect all generated transactions into genesis file
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v $(pwd)/nodes/val3:/root/.titand titand:latest validate-genesis >/dev/null

#################################################################################################################################
################################################## Chain titan_90004-1 ##########################################################
#################################################################################################################################
echo 'Chain titan_90004-1'


############################## NODES SETUP ##############################

echo 'setting up nodes...'

### On val4's machine
# initialize chain
docker run --rm -it -v $(pwd)/nodes/val4:/root/.titand titand:latest init val4 --chain-id titan_90004-1 --default-denom tkx4 >/dev/null
# config app.toml
sed -i '' '/^\[grpc\]$/,/^\[/ s/^\(address = \).*/\1\"0.0.0.0:9090\"/' $(pwd)/nodes/val4/config/app.toml
# config config.toml
sed -i '' '/^\[rpc\]$/,/^\[/ s/^\(laddr = \).*/\1\"tcp:\/\/0.0.0.0:26657\"/' $(pwd)/nodes/val4/config/config.toml
# create keyring's passphrase
printf password > ./nodes/val4/passphrase.txt
# create account
echo $(cat ./nodes/val4/passphrase.txt)$'\n'$(cat ./nodes/val4/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest keys add val4 --keyring-backend file --keyring-dir /root/.titand/keys --output json > ./nodes/val4/val4.info

############################## GENESIS SETUP ##############################

echo 'setting up genesis...'

# Change genesis setting
jq '.app_state.evm.params.evm_denom = "tkx4"' ./nodes/val4/config/genesis.json > ./nodes/val4/config/tmp.json && mv ./nodes/val4/config/tmp.json ./nodes/val4/config/genesis.json
# add val4 as genesis account with titan balance
cat ./nodes/val4/passphrase.txt | \
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest keys show val4 --address --keyring-backend file --keyring-dir /root/.titand/keys | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest add-genesis-account "{}" 100000000000000000000tkx4
# val4 stakes titan 
echo $(cat ./nodes/val4/passphrase.txt)$'\n'$(cat ./nodes/val4/passphrase.txt) | \
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest gentx val4 1000000000000000000tkx4 --keyring-backend file --keyring-dir /root/.titand/keys --chain-id titan_90004-1 >/dev/null 2>&1
# add balance for rly4
jq -r '.address' ./hermes/rly4.json | \
xargs -I {} docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest add-genesis-account {} 100000000000000000000tkx4

############################## GENESIS COMPLETE & DISTRIBUTE ##############################

echo 'genesis complete, distributing...'

### On val4's machine
# val4 collect all generated transactions into genesis file
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v $(pwd)/nodes/val4:/root/.titand titand:latest validate-genesis >/dev/null


#################################################################################################################################
################################################## relayer hermes ##########################################################
#################################################################################################################################

echo 'config relayer hermes...'

mkdir ./nodes/hermes 
cp ./hermes/config.toml ./nodes/hermes/config.toml
cp ./hermes/rly1.json ./nodes/hermes/rly1.json
cp ./hermes/rly2.json ./nodes/hermes/rly2.json
cp ./hermes/rly3.json ./nodes/hermes/rly3.json
cp ./hermes/rly4.json ./nodes/hermes/rly4.json

docker run --rm -i -v $(pwd)/nodes/hermes:/home/hermes/.hermes informalsystems/hermes:1.5.1 keys add --key-name rly1 --chain titan_18887-1 --key-file /home/hermes/.hermes/rly1.json --hd-path "m/44'/60'/0'/0/0"
docker run --rm -i -v $(pwd)/nodes/hermes:/home/hermes/.hermes informalsystems/hermes:1.5.1 keys add --key-name rly2 --chain titan_90002-1 --key-file /home/hermes/.hermes/rly2.json --hd-path "m/44'/60'/0'/0/0"
docker run --rm -i -v $(pwd)/nodes/hermes:/home/hermes/.hermes informalsystems/hermes:1.5.1 keys add --key-name rly3 --chain titan_90003-1 --key-file /home/hermes/.hermes/rly3.json --hd-path "m/44'/60'/0'/0/0"
docker run --rm -i -v $(pwd)/nodes/hermes:/home/hermes/.hermes informalsystems/hermes:1.5.1 keys add --key-name rly4 --chain titan_90004-1 --key-file /home/hermes/.hermes/rly4.json --hd-path "m/44'/60'/0'/0/0"


#################################################################################################################################

echo 'start up chain...'

docker compose -f docker-compose.yml up --wait -d val1 val2 val3 val4

echo 'create ibc channel...'
echo 'topology: 18887 <-> 90002 <-> 90003 <-> 90004 <-> 18887'

echo 'connect 18887 to 90002...'
docker compose run --rm -i hermes create \
  channel --yes --a-chain titan_18887-1 --b-chain titan_90002-1 --a-port transfer --b-port transfer --new-client-connection >/dev/null 2>&1
echo 'get channel info...'
docker compose run --rm -i hermes query \
  channels --show-counterparty --chain titan_18887-1

echo 'connect 90002 to 90003...'
docker compose run --rm -i hermes create \
  channel --yes --a-chain titan_90002-1 --b-chain titan_90003-1 --a-port transfer --b-port transfer --new-client-connection >/dev/null 2>&1
echo 'get channel info...'
docker compose run --rm -i hermes query \
  channels --show-counterparty --chain titan_90002-1

echo 'connect 90003 to 90004...'
docker compose run --rm -i hermes create \
  channel --yes --a-chain titan_90003-1 --b-chain titan_90004-1 --a-port transfer --b-port transfer --new-client-connection >/dev/null 2>&1
echo 'get channel info...'
docker compose run --rm -i hermes query \
  channels --show-counterparty --chain titan_90003-1

echo 'connect 90004 to 18887...'
docker compose run --rm -i hermes create \
  channel --yes --a-chain titan_90004-1 --b-chain titan_18887-1 --a-port transfer --b-port transfer --new-client-connection >/dev/null 2>&1
echo 'get channel info...'
docker compose run --rm -i hermes query \
  channels --show-counterparty --chain titan_90004-1

echo 'start up relayer...'

docker compose -f docker-compose.yml up -d hermes  