# Run multiple nodes - Test node connection

## A. 2 Validators same vote power not connected to each other

Basic set up with 3 basic nodes:

- 2 validators: alice + val2. both have same vote weight. Do not know to connect each other.
- 1 common node: explorer

Note: no sentries, no KMS.

RESULT: both node do not produce new block

## B. 4 Validators same vote power, 2 connected to each other

RESULT: all node not produce new block

## C. 4 Validators same vote power, 3 connected to each other

RESULT: 3 node produce new block, 1 node halt, 1 validator jailed

## D. 2 Validators, not connected to each other, 1 val have > 2/3 vote power

RESULT: node with > 2/3 vote power (not staking value) produce new block, other node halt

## E. 4 Validators, 2 connected to each other, 2 connected val have total > 2/3 vote power

RESULT: 2 node with total vote power > 2/3 produce new block, 2 node halt

## F. 2 Validators same vote power, not connected to each other, max_validators = 1

RESULT: only one node produce new block (seem like have algorithm make every node can choose same node to become validator)

## G. 4 Validators same vote power, 2 pair, max_validators = 2

RESULT (as expected):

- Sometime  2 node in pair produce new block, 2 node halt
- Sometime all 4 node halt

## How to run

For each test schema (A, B, C, D, E, F, G), there is a script_*.sh file to run the test.

```sh
# cd into examples/run-multiple-nodes/basic/
$ cd examples/run-multiple-nodes/test-node-connection/

# run
$ ./script_A.sh

# or, to run without rebuilding docker image
$ ./script_A.sh SKIP_BUILD=1

```
