# Run multiple nodes - with sentries
- 2 validators: alice + bob
- 2 sentry nodes: alice sentry + bob-sentry
- 1 common node: carol

## How to run
```sh
# cd into examples/run-multiple-nodes/with-sentries/
$ cd examples/run-multiple-nodes/with-sentries/

# run all
$ ./script.sh

# or, to run without rebuilding docker image
$ ./script.sh SKIP_BUILD=1

# query
$ docker run --rm -it --network titan-multiple-nodes-with-sentries_net-public titand:latest status --node "tcp://node-carol:26657"

$ export bob=$(cat ./nodes/bob/passphrase.txt | \
docker run --rm -i -v ./nodes/bob:/root/.titan titand:latest keys show bob --address --keyring-backend file --keyring-dir /root/.titan/keys)

$ docker run --rm -it --network titan-multiple-nodes-with-sentries_net-public titand:latest q bank balances $bob --node "tcp://node-carol:26657"

# open browser: http://localhost:26657
$ curl http://localhost:26657/genesis
$ curl http://localhost:26657/status
```