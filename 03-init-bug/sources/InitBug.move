module initbug::InitBug {
    use std::string::{Self, String};
    use std::signer::address_of;

    // To prove there is a bug we'll be using a structure
    struct InitMessage has key, store {
        // Message - which is supposed to change but it won't if
        // we change 'msg' in init_module() and the bug is present
        message: String,
        // Counter - to ensure that init_module() is actually called
        counter: u64
    }

    fun init_module(account: &signer) acquires InitMessage {
        let addr = address_of(account);
        // After first publish we need to change this to something else to prove there is a bug
        let msg = string::utf8(b"hello one");

        if(exists<InitMessage>(addr)) {
            // so basically in this scenario we got a second call to init_module()
            let im = borrow_global_mut<InitMessage>(addr);
            // let's increase counter to observe that the second call actually happend
            im.counter = im.counter + 1;
            // And let's try to change the message. If the old version of init_module()
            // get's called then this should still be "hello one" instead of some other message.
            im.message = msg;
        } else {
            let im = InitMessage { message: msg, counter: 1 };
            move_to(account, im);
        }
    }
}