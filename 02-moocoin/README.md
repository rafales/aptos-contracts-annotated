# `02-moocoin`

In this one I'm creating my first coin. In Aptos its "main coin" (cryptocurrency which is used by the chain) is implemented the same way as any other third party coin. This is different from Ethereum where ETH does not implement ERC-20 standard.

The coin standard in Aptos is implemented in multiple modules under the hood (like account) but every API we need is exposed through `aptos_framework::coin` module.

The way Aptos implements coin is extremely different from how it's done with ERC-20/Solidity/EVM. You won't be able to implement tokens with tax on transaction, you won't be able to censor other people's coins even as contract owner - on Ethereum USDC banned Coins held by Tornado Cash, this wouldn't be possible on Aptos.

## Reading

There aren't many sources in this one:

* [MooCoin.move](sources/MooCoin.move)
   - source code of our coin with some tests embedded in it
   - to run tests execute `aptos move test`
* [ctl.py](./ctl.py)
   - small python utility which uses `aptos-sdk`
   - it can interact with blockchain so that I can get a feeling of how to interact with coins
   - **IT'S BROKEN:** right now attempts to send some transactions (like `approve-coin` command)
     result in `invalid_input` error. This seems to be a bug in Aptos.


## Publishing

You may want to publish this one with `--max-gas` argument:

```shell
aptos move publish --max-gas=2000
```
