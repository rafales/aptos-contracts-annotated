module proving::Counter {
    use std::signer::address_of;

    // some errors, this is pretty standard
    const ERR_COUNTER_ALREADY_EXISTS: u64 = 123;
    const ERR_COUNTER_NOT_FOUND: u64 = 124;

    // a simple conter struct, also pretty basic at this point
    struct Counter has key {
        count: u8
    }

    // So we are creating a simple counter that we are going to test.
    // Counters will be associated with accounts, for it to work
    public fun init(addr: &signer) {
        assert!(!exists<Counter>(address_of(addr)), ERR_COUNTER_ALREADY_EXISTS);
        let counter = Counter{ count: 0 };
        move_to(addr, counter);
    }

    // This is where the fun begins!
    // "spec init" means we will write a specification for the "init" function.
    spec init {
        // so in here I think there are two important assertions we can make:
        // 1. There is only one condition in which the function
        //    can abort - when the counter already exists.
        // 2. When counter gets initialized - it starts with value 0.

        // this line tells us that if we have any abort that is not covered
        //   by "aborts_if" - it should fail. You can try commenting out lines
        //   of code to see it in action.
        pragma aborts_if_is_strict = true;
        // so with the pragma above what we mean here is that this function can only
        // abort in case where Counter already exists.
        aborts_if exists<Counter>(address_of(addr));
        // we can also limit which abort reasons are allowed
        aborts_with ERR_COUNTER_ALREADY_EXISTS;

        // now we can make an assertion on the counter value itself
        ensures global<Counter>(address_of(addr)).count == 0;

        // damn, who needs tests anymore?
        // btw you still need tests to make sure that your contracts works as intended!
    }

    // simple getter for counter value, nothing special at this point
    public fun value(addr: address): u8 acquires Counter {
        assert!(exists<Counter>(addr), ERR_COUNTER_NOT_FOUND);
        let counter = borrow_global<Counter>(addr);
        counter.count
    }

    // And now the spec. I encourage anyone reading this to play with the code,
    // change how things work and re-run prover for fun.
    spec value {
        // Ok so here's the fun thing. If you comment out this pragma and the "aborts_if"
        //   statement, this will pass. Basically prover will let us only worry about
        //   "ensures" statement while filtering out any failures like missing Counter.
        // I think you can switch this in options, I would definietly prefer being notified
        //   about aborts by default.
        pragma aborts_if_is_strict = true;
        // also - you can use "with XXX" to tell exactly which code we should abort with
        aborts_if !exists<Counter>(addr) with ERR_COUNTER_NOT_FOUND;

        // and now we can list post-conditions that need to hold
        ensures result == global<Counter>(addr).count;
    }

    public fun increment(addr: address) acquires Counter {
        assert!(exists<Counter>(addr), ERR_COUNTER_NOT_FOUND);
        let counter = borrow_global_mut<Counter>(addr);
        counter.count = counter.count + 1;
    }

    spec increment {
        pragma aborts_if_is_strict = true;
        aborts_if !exists<Counter>(addr) with ERR_COUNTER_NOT_FOUND;

        // Ok, now a few new things. First of all - we are using `u8` type in our counter,
        //  so it will overflow easily. Prover catches that. It's up to us how we are going
        //  to handle that. Our choice for now - ignore.
        // By using 'require' we are saying that this spec should not run unless the
        //   pre-conditions are met.
        requires global<Counter>(addr).count < 255;

        // Second new thing is old() xD
        // `ensures` is called on a state after function execution.
        // We can access state before `execution` by calling `old()`.
        // That way we can assert that function increases counter by 1.

        ensures global<Counter>(addr).count == old(global<Counter>(addr).count) + 1;
    }
}