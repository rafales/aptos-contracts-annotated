# `04-time-vault`

Common use case in Solidity / EVM is locking coins for a period of time:

* User deposits ERC-20 tokens / Ether to the contract
* Contract saves information about how long is given amount of tokens locked for
* Hacker hacks the contract, draining all tokens
* **SADFACE**
* The problem here is that while tokens belong to the user they are kept on the contract's account

Move/Aptos advocate for a completely different approach:

* coins are implemented via `aptos_framework::coin`.
* its main struct is `Coin<T>`, which can't be copied or destroyed (no `copy` and `drop` abilities).
* but `Coin<T>` can be stored anywhere
* it means that you can withdraw `Coin<T>` with given amount of coins and store it somewhere else
* like in `CoinTimeVault` structure in user's account
* `Coin<T>` behaves like a physical pile of coins:
  * it can be merged with another pile (`coin::merge()`)
  * it can be split into multiple piles (`coin::extract()`)
  * it can be deposited or withdrawn from user's "bank account" (`coin::withdraw()`, `coin::deposit()`)
  * it can be stored under your bed or in a sock (by that I mean other places like `CoinTimeVault`)
  * it can be moved around
  * but it can't be copied, and it can't be destroyed
* this is the magic of Move!
* so architecture of this module is pretty simple:
  * user withdraws coins from their bank account (`coin::withdraw()`)
  * they give us the pile of coins (`Coin<T>` instance)
  * we put this pile of coins in a `CoinTimeVault<T>`, which you can think of
     as a vault with multiple deposit boxes (`Tranche<t>`), each of them with a time lock
  * we put that `CoinTimeVault<T>` back in user's account
* notice that we are operating on everything like on physical objects!
* this wouldn't be safe in a regular language!

## Reading

Annotated code is stored in one file:

* [TimeVault.move](./sources/TimeVault.move)


## Publishing

You may want to publish this one with `--max-gas` argument:

```shell
aptos move publish --max-gas=2000
```
