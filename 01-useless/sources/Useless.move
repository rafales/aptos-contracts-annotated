/* So this is a completely useless module. Anyone using it will be able to say their name.
 * Not even events fired, utterly useless. But it's enough to deploy a working contract. */

/* so `useless` here is not a package name, it's a named address. Modules live in addresses. Duh.
 * if you don't know what named address is - check `Move.toml`. */
module useless::Useless {
    /* Where the heck does this (std::) comes from? We didn't import any std:: dependencies!
     * The answer is - AptosFramework. It defines aptos_framework, std, aptos_std and some other named addresses for us. */
    use std::signer;
    use std::string::{String};

    // As I said - uterrly useless. It allows you to introduce yourself. And that's it.
    //  This struct needs at least `key` ability so I can place it in account's global storage.
    struct Passport has key, store {
        name: String
    }

    // This is a funny story. So I created this thing here, even deployed it. But running it
    // returned an error because ENTRY FUNCTIONS CAN'T RETURN VALUES! Freaking compiler didn't
    // warn me about that. But now that it was deployed - Prover won't allow me to remove it
    // because it would break the public interface of my module. So I'm leaving it as a lesson.
    public entry fun main(_account: &signer): address {
        // So this is interesting - if you need to use named address as a value.
        // Another interesting thing - you don't need to write a "return" statement. Just like in
        // some languages (Rust, Ruby I think) - the last expression is automatically return statement. */
        @useless
    }

    // So - what the heck is "entry" actually? Normal "public" functions can only be called
    //from other modules. If we want our transaction to start at "say_your_name()" then we need
    //to mark it as entry (more or less). You may see `public(script)` in some places as well - that syntax
    //basically does the same thing but it's deprecated.
    public entry fun say_your_name(account: signer, name: String) acquires Passport {
        // 1. We have to explicitly tell compiler that we'll be acquiring SimpleStorage from global storage
        //   Global storage is basically per-account object store.
        // 2. We require a "signer" instance in our arguments which will be filled automatically based on
        //   who signed the transaction.

        // Signer is not an address, we need to call "address_of" to figure out who signer actually is.
        // This is a bit different from "msg.sender" in Solidity.
        let by = signer::address_of(&account);

        // Ok, so in Solidity we are restricted to storing data in our own (contract's) account. This is
        // not true with Move. We can store data in any accounts (yep, with our contract's account too!).
        // So the typical pattern here is to keep data in user's account if possible.

        // Another interesting thing is that we can only store one instance of a given struct in an account.
        // So first we need to check if it doesn't exist yet:
        if(!exists<Passport>(by)) {
            // So if it doesn't exist then we can create/move our new struct to that account.
            let s = Passport { name };
            // But notice that move_to() actually uses "signer" instance, not "address". This is important
            // because you can't conjure a signer from air! It's only available if someone signed the transaction.
            // This means that we can only add new structs to accounts if users allow it. We can't do this for
            // any account. This means no spamming with random coins/NFTs etc.
            move_to(&account, s);
        } else {
            // but if the struct already exists in account - then we (module who declares the struct)
            // can modify it freely without needing a signer.
            let s = borrow_global_mut<Passport>(by);
            s.name = name;
        }
    }
}
