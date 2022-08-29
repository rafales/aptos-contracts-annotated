# `03-init-bug`

A minimal example of a bug I have found with `init_module()`. `init_module()` is supposed to be called when initializing module. Right now it's called on upgrades as well. This is not a problem in itself as it would be easy to work around. The problem is that on upgrade an OLD VERSION of `init_module()` gets called. And this code is a minimal example which demonstrates that.

To test the theory you need to change `msg` in code after upgrading, publish again and observe changes to `counter` and `message` stored on chain.

See: https://github.com/aptos-labs/aptos-core/issues/3573

