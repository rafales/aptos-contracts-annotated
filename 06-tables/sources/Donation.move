// Not the best example of how tables work but I wanted something isolated to test it.
// It may not be the best design but that way we can test tables :)
module tables::Donation {
    use std::error;
    use std::signer::address_of;
    use aptos_framework::coin;
    use aptos_std::table_with_length::TableWithLength;
    use aptos_std::table_with_length;

    // I believe this is the first time I'm doing errors right. Abort allows only for
    //   a u64 error code, no more information can be returned. That's why `std:error` exists.
    // Basically the split u64 into 16 bits for a "category" and the rest for specific information.
    // Then we use a helper like already_exists(specific_info), eg. already_exists(DONATION_LEDGER)
    //   to generate an error code.
    // Granted - this is far from perfect (solidity has an event type which is more flexible),
    //   but this model is definietly an improvement over magic u64 number.
    const DONATION_LEDGER: u64 = 1;

    struct Donor has store {
        // let's say that we have an ability to ban a given donor
        blocked: bool,
    }

    struct DonationLedger<phantom CoinType> has key {
        donors: TableWithLength<address, Donor>,
    }

    // So this is first time I'm using schemas! Schemas are basically reusable fragments
    // of specifications.
    spec schema AbortsUnlessAcceptsDonations<CoinType> {
        // We define an "addr" as a variable that we expect to be in scope
        // when we include the schema.
        addr: address;
        // CoinType here is another type we simply expect to be there.
        aborts_if exists<DonationLedger<CoinType>>(addr);
        aborts_with error::already_exists(DONATION_LEDGER);
    }

    // Someone who wishes to accept donations has to call this to start accepting
    // donations in given coin.
    public entry fun accept_donations<CoinType>(account: &signer) {
        check_accepts_donations<CoinType>(address_of(account));
        move_to(account, DonationLedger<CoinType>{ donors: table_with_length::new()});
    }

    fun check_accepts_donations<CoinType>(addr: address) {
        assert!(!exists<DonationLedger<CoinType>>(addr), error::already_exists(DONATION_LEDGER));
    }

    spec check_accepts_donations {
        // these rules are checked by AbortsUnlessAcceptsDonations schema
        pragma aborts_if_is_strict = false;
    }

    public entry fun accepts_donations<CoinType>(addr: address): bool {
        exists<DonationLedger<CoinType>>(addr)
    }

    spec accept_donations {
        // so we can use our own variables in specs
        let addr = address_of(account);
        // We can easily include schemas. Notice that we have "addr" and "CoinType" in scope
        include AbortsUnlessAcceptsDonations<CoinType>;
        // Notice that we may use "accepts_donations" which is a Move function :) This doesn't work
        // for all functions (eg functions which mutate state), but it does for this one.
        ensures accepts_donations<CoinType>(addr);
        // The only way for this function to success is if we weren't accepting donations before.
        // So we can validate this rule by using old() helper.
        ensures old(accepts_donations<CoinType>(addr)) == false;
    }

    public fun donate_coin<CoinType>(to: address, coin: coin::Coin<CoinType>) {
        check_accepts_donations<CoinType>(to);
        coin::deposit(to, coin);
    }

    spec donate_coin {
        // Thanks to this rule we don't have to enumerate all abort cases.
        // This is because coin::deposit() may fail in multiple ways, so no point
        //   in enumerating all of them.
        pragma aborts_if_is_partial;

        pragma aborts_if_is_strict = false;
        // We will still list all possible error codes to make sure we're not failing in some unexpected way.
        aborts_with error::not_found(coin::ECOIN_STORE_NOT_PUBLISHED), error::permission_denied(coin::EFROZEN);
        aborts_with EXECUTION_FAILURE;
        include AbortsUnlessAcceptsDonations<CoinType>{addr: to};

        ensures coin::balance<CoinType>(to) == coin::value(coin) + old(coin::balance<CoinType>(to));
    }

    spec module {
        // We can set "aborts_if_is_strict" on module level, so it will apply to everything
        // When we set it then each unexpected abort will trigger a failure.
        pragma aborts_if_is_strict = true;
    }
}