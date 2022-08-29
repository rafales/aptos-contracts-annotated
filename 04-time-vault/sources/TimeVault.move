module timevault::TimeVault {
    use aptos_framework::coin;
    use std::signer::address_of;
    use std::vector;
    use aptos_framework::timestamp;

    const UT_ERR: u64 = 123;

    // So we will be storing tranches in user's account.
    // As user can lock one coin multiple times with multiple locking periods
    //   we will need a vector instead of a single tranche.
    struct CoinTimeVault<phantom T> has key {
        tranches: vector<Tranche<T>>,
    }

    // Tranche is a single locking period for a coin.
    // Now - instead of storing amount of coin we store an instance of Coin<T>.
    //   This is why Move is amazing - Coin<T> is not simply a "json object" to keep "value" field.
    //   If we have a Coin<T> instance it's like we are holding actual coins in our hands.
    //   We can't copy it, we can't destroy it. It is like a pile of physical coins.
    //   But we can split the piles (coin::extract()), merge them (coin::merge()),
    //     deposit into bank (coin::deposit()), withdraw from bank (coin::withdraw()) etc.
    //   We can store them in different places or even lock in boxes with time locks (like Tranche).
    //   If you think about it like that - it's pure magic.
    struct Tranche<phantom T> has store {
        coin: coin::Coin<T>,
        locked_until: u64
    }

    // This function locks given coins until given timestamp (in seconds)
    // Note that it's totally safe to accept 'coin' here - as Coin<T> can't be copied
    //   or acquired from thin air.
    public fun lock<T>(account: &signer, coin: coin::Coin<T>, locked_until: u64) acquires CoinTimeVault {
        if(!exists<CoinTimeVault<T>>(address_of(account))) {
            move_to(account, CoinTimeVault<T>{tranches: vector::empty()});
        };

        let tranche = Tranche { coin, locked_until };
        let vault = borrow_global_mut<CoinTimeVault<T>>(address_of(account));
        vector::push_back(&mut vault.tranches, tranche);
    }

    // Similar to lock() but can be entry point to a transaction.
    public entry fun deposit<T>(account: &signer, amount: u64, locked_until: u64) acquires CoinTimeVault {
        // We need to withdraw the coins first from the account
        let coin = coin::withdraw<T>(account, amount);
        // Then we can take this pile of coins and lock them.
        // In any other language this would be unsafe and any user could create a structure
        // and modify it's value, but Move is special like that. Because coin::Coin doesn't have "copy"
        // ability you can think of it as physical pile of coins.
        lock(account, coin, locked_until);
    }

    // This function finds all tranches which can be unlocked, unlocks the coin and returns them.
    public fun unlock_all<T>(account: &signer): coin::Coin<T> acquires CoinTimeVault {
        let now = timestamp::now_seconds();

        // So let's make this function super safe - if user didn't really have anything locked
        // then let's simply return no coins instead of aborting.
        if(!exists<CoinTimeVault<T>>(address_of(account))) {
            // Notice that the only case where anyone can conjure coins of thin air
            // is if the pile of coins contains 0 coins.
            return coin::zero<T>()
        };

        let vault = borrow_global_mut<CoinTimeVault<T>>(address_of(account));
        let unlocked = coin::zero<T>();
        let i = 0;

        while (i < vector::length(&vault.tranches)) {
            let tranche = vector::borrow(&vault.tranches, i);
            if (tranche.locked_until <= now) {
                let tranche = vector::swap_remove(&mut vault.tranches, i);
                // Notice that destruction syntax in Move has special meaning.
                // In JS or other languages it basically is a nice syntax to assign multiple local
                //   variables in a single line.
                // In move when destructed - 'tranche' here will cease to exist.
                let Tranche { coin, locked_until: _ } = tranche;
                // Now in the next line - we are merging 'coin' to 'unlocked' and 'coin' will cease to exist.
                coin::merge(&mut unlocked, coin);
            } else {
                i = i + 1;
            }
        };

        unlocked
    }

    // So this function is similar to what unlock_all() does, but:
    //  - it's an entry point so it can be an entry point to a transaction
    //  - it deposits the unlocked coins in user's account
    public entry fun withdraw_all<T>(account: &signer) acquires CoinTimeVault {
        // we unlock the available coins first
        let unlocked = unlock_all(account);

        if(coin::value(&unlocked) == 0) {
            // If value is 0 then we don't want to do anything and simply return.
            // But guess what - we can't abandon a pile of coins!
            // Why not? Because Move type system doesn't know it's pile of 0 coins.
            // All it sees is a pile of coins which can't be destroyed automatically (no `drop` ability).
            // Luckily coin module provides us with an escape hatch:
            coin::destroy_zero(unlocked);
            return
        };

        // Let's make sure user is registered for coin if they want to withdraw.
        if(!coin::is_account_registered<T>(address_of(account))) {
            coin::register<T>(account);
        };

        coin::deposit<T>(address_of(account), unlocked);
    }

    // So this is the end!
    // It's a nice contract which allows users to lock their coins for given period of time.
    // It's a completely different approach than what I know from Solidity or Ethereum.
    // But it's nice. It's safe. It's simple. It's powerful. (This line was actually written by GitHub Copilot lol).

    // One can imagine additional extensions:
    //  - allow for withdrawing only a single tranche
    //  - allow for withdrawing a selected amount of coins
    //  - allow for transfering tranches to different accounts while maintaining locks

    // But I got all I wanted from this contract - understanding of how objects can be moved
    // around safely and stored in user's account. And it's pure magic.

    #[test_only]
    use aptos_framework::account::create_account_for_test;
    #[test_only]
    use aptos_framework::managed_coin;
    #[test_only]
    struct FakeMoney {}

    #[test_only]
    fun init_money(source: &signer) {
        // Managed coin is super useful for testing.
        // There is coin::create_fake_money() but it seems cumbersome to work with
        // and probably meant only for internal testing and exposed by mistake.
        managed_coin::initialize<FakeMoney>(source, b"FakeMoney", b"FAKE", 8, false);
    }

    // I'm only including some basic tests here. I'm sure you can come up with more.
    // But my goal is already achieved so only basic testing.
    // I'll be testing testing capabilities of Move when I get to prover and specs.

    #[test(fw=@aptos_framework)]
    fun withdrawing_zero_is_safe(fw: &signer) acquires CoinTimeVault {
        timestamp::set_time_has_started_for_testing(fw);

        let root = create_account_for_test(@timevault);
        let alice = create_account_for_test(@0xEEEEEEE1);
        init_money(&root);

        // Alice is not registered and doesn't hold any coins. But our assumption is
        // that it doesn't fail.
        withdraw_all<coin::FakeMoney>(&alice);
    }

    #[test(fw=@aptos_framework)]
    fun unlocking_scenario(fw: &signer) acquires CoinTimeVault {
        timestamp::set_time_has_started_for_testing(fw);

        let root = create_account_for_test(@timevault);
        let alice = create_account_for_test(@0xEEEEEEE1);

        init_money(&root);
        coin::register<FakeMoney>(&alice);
        managed_coin::mint<FakeMoney>(&root, address_of(&alice), 500);

        let now = timestamp::now_seconds();
        deposit<FakeMoney>(&alice, 200, now + 360);
        assert!(coin::balance<FakeMoney>(address_of(&alice)) == 300, UT_ERR);

        timestamp::fast_forward_seconds(360 + 1);
        withdraw_all<FakeMoney>(&alice);

        assert!(coin::balance<FakeMoney>(address_of(&alice)) == 500, UT_ERR);
    }
}
