# IBC Fundamentals

2 chain can connect each other via IBC protocol.
In each chain need to have a light client of other chain. It can verify information from another chain.
With chain base con cosmos sdk (it already has tendermint client (ibc go) ). To order to communicate with other chain, we need to have a `relayer`. 

`relayer` is a program that can relay a packet from one chain to another chain. `relayer` manage an address in each chain to submit transactions on each chain. It listen event from one chain and then send a transaction to another chain. Information in that transaction is verified by light client of that chain. that why relayer is trustless and anyone can run a relayer.

**NOTE:** relayer need account on each chain and also balance in those account to pay gas fee. (need dig further into `recv` option in hermes config)

# Token transfer

IBC module of cosmossdk support transfer token between chain. it listen on port `transfer`. So to order to transfer tokens between 2 cosmos chains, we only need run a relayer and setup a channel between 2 chain.

## IBC denom

when a token is transfer to another chain, it exist in another chain by and ibc id that created by formula 

```
ibc_denom := 'ibc/' + hash('path' + 'base_denom')
```

where `path` is `{portID}/{channelID}/`. `portID` and `channelID` is the id of port and channel of chain that received token.

When token is transferred via multiple hops, the above formula will be applied multiple times.

**NOTE:** That mean one token of one chain can present in another chain with many ibc denom depend on channel that was received. And if token be transferred via path like this `chainA -> chainB -> chainC -> chainA`, it will be present in chainA with ibc denom contain info of all path it traveled (**NOT original demon**). SO the correct path must be `chainA -> chainB -> chainC -> chainB -> chainA` to make sure token is transferred back to chainA to become the original token.

# Multiple chain Scenario setup

run script `./script.sh` to setup 4 chains with chain id: `titan_90000-1`, `titan_90002-1`, `titan_90003-1`, `titan_90004-1`

and one relayer with configured topology : 90000 <-> 90002 <-> 90003 <-> 90004 <-> 90000

# Test scenario

## Transfer token from 90000 to 90002

1. Send the transaction to transfer token from 90000 to 90002 via relayer

check channel connect between 90000 and 90002

```shell
docker exec -it titan-multiple-chains-with-relayer-hermes-1 hermes query channels --show-counterparty --chain titan_90000-1
```

You will something like this :

```shell
titan_90000-1: transfer/channel-0 --- titan_90002-1: transfer/channel-0
titan_90000-1: transfer/channel-1 --- titan_90004-1: transfer/channel-1
```

That mean 90000 and 90002 have a channel connect channel-0:transfer to channel-0:transfer
So to send token from 90000 to 90002:

```shell
docker exec -it titan-multiple-chains-with-relayer-hermes-1 hermes tx ft-transfer --src-chain titan_90000-1 --dst-chain titan_90002-1 --src-port transfer --src-channel channel-0 --amount 1000 --denom titan --timeout-height-offset 1000
```

The above command is not specified from address and to address. Hermes default use addresses that it controls on each chain. If you want to specify from address and to address, you can use `--key-name` and `--receiver` flag.

This only use to fast test transfer. In real life, you should want to direct interact with source chain to do this. (method 2)

2. Send the transaction to transfer token from 90000 to 90002 via 90000 node

This is how use node command cli to send a token to 90002 chain.

```shell
docker exec -it titan-multiple-chains-with-relayer-val1-1 titand tx ibc-transfer transfer transfer channel-0 titan162k6urmsksdhej59x5y4wdh2fj4kk6035zqf99 1000titan --from val1 --keyring-backend file --keyring-dir /root/.titan/keys
```