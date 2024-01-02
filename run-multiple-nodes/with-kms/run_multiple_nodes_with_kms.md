# Run multiple nodes - with sentries and tendermint kms
- 2 validators: alice + bob
- 2 sentry nodes: alice sentry + bob-sentry
- 1 tendermint kms for validator alice (https://github.com/iqlusioninc/tmkms)
- 1 common node: carol

## How to run
```sh
# cd into examples/run-multiple-nodes/with-kms/
$ cd examples/run-multiple-nodes/with-kms/

# run all
$ ./script.sh

# or, to run without rebuilding docker images
$ ./script.sh SKIP_BUILD=1 SKIP_KMS_BUILD=1

# query
$ docker run --rm -it --network titan-multiple-nodes-with-kms_net-public titand:latest status --node "tcp://node-carol:26657"

$ export bob=$(cat ./nodes/bob/passphrase.txt | \
docker run --rm -i -v ./nodes/bob:/root/.titand titand:latest keys show bob --address --keyring-backend file --keyring-dir /root/.titand/keys)

$ docker run --rm -it --network titan-multiple-nodes-with-kms_net-public titand:latest q bank balances $bob --node "tcp://node-carol:26657"

# open browser: http://localhost:26657
$ curl http://localhost:26657/genesis
$ curl http://localhost:26657/status
```