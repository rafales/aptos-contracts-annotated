module moocoin::MooCoin {
    use std::option::{Self, Option};
    use std::signer::{address_of};
    use std::string;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability, FreezeCapability};

    // Marking something as #[test_only] means it will only be compiled for the unit test version.
    // This allows us to create test-only APIs.
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    // I'm going to use UT_ERR for asserts in unit tests. For now I don't see any reason
    // to use anything else as I can see where the error occurred.
    #[test_only]
    const UT_ERR: u64 = 1;

    // A "phantom type" for our coin. You can read more about phantom type parameters
    // here: https://move-language.github.io/move/generics.html#phantom-type-parameters
    struct MooCoin has key {}

    // Here we will keep a "capability" or "token" which allows for minting, burning and freezing.
    // Whole mechanism is explained later under coin::initialize() call.
    struct CapStore has key, store {
        // We use "Option" type which is a sane replacement for None / null.
        // Thanks to that we will be able to get rid of capabilities if we don't want them
        // anymore.
        mint: Option<MintCapability<MooCoin>>,
        burn: Option<BurnCapability<MooCoin>>,
        freeze: Option<FreezeCapability<MooCoin>>
    }

    // Init module will be called when instantiating the module. This is where we will
    // do our init work. `signer` will be the account signing the transaction and hosting the modules.

    fun init_module(source: &signer) {
        // Right now it's being called every time we upgrade the module as well.
        // Not sure if this is the final semantics.
        // Another problem is that the module being called on upgrade is the old version, not new version.
        // See: https://github.com/aptos-labs/aptos-core/issues/3573
        // This is why we do a check to see if the coin was already initialized and bail out.
        if(exists<CapStore>(address_of(source))) {
            return
        };

        // We are using our phantom struct to register our shiny MooCoin with coin module. Internally
        // it will create a CoinInfo struct which holds name, symbol etc for the coin.
        let (cap_burn, cap_freeze, cap_mint) = coin::initialize<MooCoin>(source, string::utf8(b"MooCoin"), string::utf8(b"MOO"), 8, true);
        // In return we've got 3 values - capabilities. And it's super interesting idea! Here is how they work:
        // 1. Only coin module can create an instance of BurnCapability etc.
        // 2. coin::initialize() validates that ONLY WE (meaning the account which defines MooCoin struct)
        //    can call it.
        // 3. This means that at this point only we hold an instance of BurnCapability and no one else
        //    can access or create it.
        // 4. At this point we may decide to drop it or to store it in global storage.
        // 5. If we decide to store it then we can store it - then anyone who can get their hands on
        //    an instance of capability can burn coins.
        // 6. If we store it then we can use coin::burn() to burn coints, coin::mint() to mint etc.
        // 7. FreezeCapability is super dangerous as it allows for freezing all transfers.

        // Here is the funny thing - the way the Coin standard is implemented on aptos -
        // users need to register a coin first before they can receive it. And notice that
        // you need to do it with signer, so there is no way to airdrop someone a spam token.
        // While this will probably be better for security - UX may suffer.

        // Anyway, we register our main account for the token - which internally will store CoinStore<MooCoin>
        // on our account.
        coin::register<MooCoin>(source);

        // And now that we've registered our account for tokens - let's give ourselves some coins!
        // Notice that I need to hold a reference to MintCapability. As I said earlier - the only way
        // to get one is to get it from coin::initialize().

        let minted = coin::mint<MooCoin>(1000 ^ 8, &cap_mint);

        // When I simply ignored return value of coin::mint() because I forgot that I need to
        // deposit it - compiler complained!
        // Coin<T> doesn't have "drop" ability, meaning I can't just mint coins and then
        // forget about them. I must deposit them somewhere. This is power of Move.

        // So let's deposit them to our own account
        coin::deposit(address_of(source), minted);

        // We've seen that we int MintCapability instance to mint new tokens - but it's only available
        // from coin::initialize()! So what do we do? The way Move works we can simply store it in
        // global storage and retrieve when needed! This feels weird but also ingenious.
        let caps = CapStore {
            mint: option::some(cap_mint),
            burn: option::some(cap_burn),
            freeze: option::some(cap_freeze)
        };
        move_to(source, caps);
    }

    // This function allows contract owner to mint new tokens to a given account.
    public entry fun mint(account: &signer, amount: u64, to: address) acquires CapStore {
        // Minting is only possible if we hold a MintCapability. We stored it in global storage.
        let caps = borrow_global<CapStore>(address_of(account));
        // Minting and deposit are two separate operations.
        // This is safe because Coin<MooCoin> does not have "drop" ability, so
        // we can't simply forget about it without depositing.
        let minted = coin::mint(amount, option::borrow(&caps.mint));
        coin::deposit(to, minted);
    }

    // Compared to ERC-20 - Aptos will not allow us to send tokens to someone who do not wish
    // to receive them. User needs to call register() first. coin::register() is not an entry
    // function so we need to create a wrapper for it.
    public entry fun register(account: &signer) {
        coin::register<MooCoin>(account);
    }

    // So this is cool - you can embed tests in the module itself by marking it with #[test].
    // It won't be included in the final build.
    #[test]
    fun mint_new_tokens() acquires CapStore {
        // We can get our hands on signer instances by calling create_account_for_test().
        // It's only available during testing.
        // And it will automatically set up account for us.
        let root = create_account_for_test(@moocoin);
        let user = create_account_for_test(@0x123456);

        // Now we need to manually init our module.
        init_module(&root);

        // for mint to work user needs to register for that coin first
        coin::register<MooCoin>(&user);
        let amount = 10000 ^ 8;

        // Let's make sure sure that user has 0 balance - to be safe.
        // Assert takes two arguments. Firt one is the condition which must be true.
        // Second is u64 code which we can use to provide more information about the error.
        // But during unit testing code isn't really useful.
        assert!(coin::balance<MooCoin>(address_of(&user)) == 0, UT_ERR);

        // And finally we can mint!
        mint(&root, amount, address_of(&user));

        // Finally the assert to make sure user received the tokens.
        assert!(coin::balance<MooCoin>(address_of(&user)) == amount, UT_ERR);
    }

    #[test]
    fun init_registers_root_for_coin() {
        // ok, so this one simply tests if init_module() automatically registers
        // our root account for MooCoin so that we don't have to do it manually later.
        let root = create_account_for_test(@moocoin);
        init_module(&root);

        assert!(coin::is_account_registered<MooCoin>(@moocoin), UT_ERR);
    }

    #[test]
    fun init_can_be_called_safely_twice() {
        // at the moment init_module() is being called each time we publish
        // we need to make sure it can be called many times without breaking
        let root = create_account_for_test(@moocoin);
        init_module(&root);
        init_module(&root);

        assert!(exists<CapStore>(@moocoin), UT_ERR);
    }
}