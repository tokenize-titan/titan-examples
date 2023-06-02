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
	docker build -f ../../Dockerfile ../../ -t titand:latest
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

# add alice as genesis account with tkx balance
cat ./nodes/alice/passphrase.txt | \
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest keys show alice --address --keyring-backend file --keyring-dir /root/.titan/keys | \
xargs -I {} docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest add-genesis-account "{}" 10000tkx
# alice stakes tkx 
echo $(cat ./nodes/alice/passphrase.txt)$'\n'$(cat ./nodes/alice/passphrase.txt) | \
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest gentx alice 1000tkx --keyring-backend file --keyring-dir /root/.titan/keys --chain-id titan-1 >/dev/null 2>&1

# alice collect all generated transactions into genesis file
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest collect-gentxs >/dev/null 2>&1
# validate the genesis file
docker run --rm -i -v ./nodes/alice:/root/.titan titand:latest validate-genesis >/dev/null

# alice exposes his backend, makes it accessible/usable from outside world
sed -i '' 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ./nodes/alice/config/config.toml

docker compose -f docker-compose.yml up -d
