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
               --etherscan-api-key <etherscan_api_key> \
               -- verify \
               DynamicTokenURI
```

Then call `setExtensionConfig()` to configure the following parameters
for a creator contract:
* `baseURI`: base URI to be used for all tokens minted by the extension
* `maxSupply`: the number of artworks and also the maximum number of tokens
to be minted by the extension
* `mintCost`: the cost of minting. Can be zero.

Once the extension is deployed, it can be registered in the creator contract
by calling `registerExtension()` in the creator contract.

### Configure token URIs

By default it is assumed that the metadata directory follows a specific structure:
```console
.
└──<baseURI>
   ├── 1.json
   ├── 2.json
   ├── ...
   └── <maxSupply>.json
```
eg., the token URI for a token without any transfers will be `${baseURI}1.json`,
the token URI for a token with a single transfer will be `${baseURI}2.json`, etc.

In case the metadata files are not named after numbers indexed from 1 up to the
maximum supply of artworks, `setTokenURIs()` can be called on the extension to
map the numbers to fully qualified token URIs,
eg., `setTokenURIs(creatorContract,[1,2,..],["ar://bla420", "ar://bla69",...])`
will force tokens without a transfer to point to `"ar://bla420"`, tokens with a
single transfer to point to `"ar://bla69"`, etc.

## Manifold extensions

Learn more about Manifold extensions:
* [developing](https://docs.manifold.xyz/v/manifold-for-developers/smart-contracts/manifold-creator/contracts/extensions)
* [deploying](https://docs.manifold.xyz/v/manifold-for-developers/smart-contracts/manifold-creator/contracts/extensions/extensions-deployment-guide)
