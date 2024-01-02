# Run multiple nodes - Basic
Basic set up with 3 basic nodes:
- 2 validators: alice + bob
- 1 common node: carol

Note: no sentries, no KMS.

## How to run
```sh
# cd into examples/run-multiple-nodes/basic/
$ cd examples/run-multiple-nodes/basic/

# run all
$ ./script.sh

# or, to run without rebuilding docker image
$ ./script.sh SKIP_BUILD=1

# query
$ docker run --rm -it --network titan-chain-basic_net-public titand:latest status --node "tcp://node-carol:26657"

$ export bob=$(cat ./nodes/bob/passphrase.txt | \
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest keys show bob --address --keyring-backend file --keyring-dir /root/.titand/keys)

$ docker run --rm -it --network titan-chain-basic_net-public titand:latest q bank balances $bob --node "tcp://node-carol:26657"

# open browser: http://localhost:26657
$ curl http://localhost:26657/genesis
$ curl http://localhost:26657/status
```