# Manifold extension for dynamic URIs

`DynamicTokenURI` is a Manifold extension that enables dynamic token URIs
for a Manifold creator contract. Specifically, when a token is transferred
between wallets, the URI changes. [Foundry](https://book.getfoundry.sh/) is
used to build, test, and deploy the contract.

## Build

```console
$ forge install
$ forge build
$ forge test
$ forge fmt
```

## Deploy

```console
$ forge create --rpc-url <rpc_url> \
               --private-key <private_key> \
               --constructor-args <creator_contract>,<base_uri> \
               --etherscan-api-key <etherscan_api_key> \
               -- verify \
               DynamicTokenURI24
```

## Manifold extensions

Learn more about Manifold extensions:
* [developing](https://docs.manifold.xyz/v/manifold-for-developers/smart-contracts/manifold-creator/contracts/extensions)
* [deploying](https://docs.manifold.xyz/v/manifold-for-developers/smart-contracts/manifold-creator/contracts/extensions/extensions-deployment-guide)
