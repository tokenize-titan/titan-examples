# Run a single node / validator

## Requirements
- Go 1.19

## Build the executable
```sh
# Install Go packages
$ go mod tidy

# Build the executable
$ make install

# Run
$ titand --help

# or
$ ./build/titand --help
```

## Run a node

### 1. Initialize the chain home directory
```sh
# Remove the old one (can skip this on first time initialization)
rm -rf ./private/.titan

# Init the home dir
titand init demo --home ./private/.titan --chain-id titan-1 --default-denom tkx
```

The initialization creates `.titan` directory under `private/`, which contains:
```
.titan
|-- config
    |-- app.toml
    |-- client.toml
    |-- config.toml
    |-- genesis.json
    |-- node_key.json
    |-- priv_validator_key.json
|-- data                               <- blockchain DB
    |-- priv_validator_state.json
    |-- ...
```

Inspect the initial configuration:
```sh
$ cat private/.titan/config/genesis.json
```

### 2. Prepare an account
```sh
# Inspect current keys
$ titand keys list --home private/.titan --keyring-backend test
```
In case there is no keys yet, the output should be `[]` and a new directory `keyring-test/` will be created under home dir `./private/.titan`.

```sh
# Add a new key
$ titand keys add alice --home private/.titan --keyring-backend test

# Inspect the key list again, confirm alice has been added
$ titand keys list --home private/.titan --keyring-backend test

```

### 2. Make that account become a validator
```sh
# Add alice as genesis account
$ titand add-genesis-account alice 100000000tkx --home private/.titan --keyring-backend test

# Include bootstrap transactions
$ titand gentx alice 70000000tkx --home private/.titan --keyring-backend test --chain-id titan-1

# Collect genesis transactions
$ titand collect-gentxs --home private/.titan
```

### 3. Start the chain
```sh
$ titand start --home private/.titan
```

### 4. Interact with the chain
Query `alice` balance:
```sh
# Get alice address
$ export alice=$(titand keys show alice --address --home private/.titan --keyring-backend test) && echo $alice

$ titand q bank balances $alice
```

Transfer `1000tkx` to `bob`:
```sh
# Pick a random address for bob
$ export bob=titan1zkvm385sylhksh5z4ctyzpkx7t360jzev0m5mc

# Choose "yes" when prompted to sign the tx
$ titand tx bank send $alice $bob 1000tkx --home private/.titan --keyring-backend test --chain-id titan-1

# Show transaction info
$ titand q tx <txhash>

# Check bob's balance
$ titand q bank balances $bob

# Check alice's balance
$ titand q bank balances $alice
```

## References:
- https://tutorials.cosmos.network/tutorials/3-run-node/
