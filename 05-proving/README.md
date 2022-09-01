# `05-proving`

## Formal Verification

Spoiler alert: I'm a formal verification nut.

Here's the thing - when writing regular software unit tests are great. Sure, there are some conditions and edge cases that we need to anticipate and make sure that our code works in given set of conditions. Unit testing (and other levels of tests) work great for regular software. But with regular software we have layers on layers of security nets:

- so you made a SQL injection? Don't even know how you managed that in these times, but it's fine because your DevOps guy set up WAF which catches any attempts to do so!
- you made an XSS? This is fine because CSP someone set up won't allow attacker to do much
- or maybe another mistake but your company relies on principle of least privilege so there isn't much impact

I can go on. But security is a game of layers, barriers, boundaries set up in such way that failure in one place will prevent an incident or at least dramatically reduce impact.

**This is not true with smart contracts.**

With smart contracts you put your code out there, for anyone to hack, without any safety nets. It's a wild west or - as some prefer to call it - a dark forrest. In such conditions unit tests are just not enough. Unit tests don't prove that your code works under all conditions. They just prove they work in a given set of scenarios. But there can be something in your code that you didn't anticipate - but someone finds it and can leverage it. What's worse - **you are outnumbered**. No matter how big is your team - the collective of hackers out there is much bigger.

How better would it be if we could prove statements like:

* total sum of all accounts always equal `supply`
* value `x` never gets bigger than `10`
* this function aborts only with a given set of conditions

and be able to prove that beyond any doubt?

This is what Formal Verification is for.

## Move Prover

Move was created to be a safe language. And it does a lot in terms of language design to achieve that. It also comes with a tool - move prover - to aid developers where language itself is not enough. Sadly I have not found any good tutorials on it (we are still early). But there is enough materials to get us through this:

1. [User guide](https://github.com/move-language/move/blob/main/language/move-prover/doc/user/prover-guide.md) where you can learn how to run it.
2. [Move Specification Language doc](https://github.com/move-language/move/blob/main/language/move-prover/doc/user/spec-lang.md) to learn what syntax and constructs is available.
3. Tons of samples in frameworks: stdlib, aptos stdlib, aptos framework.

It's not going to be easy but totally doable.

## Getting started

* Prover uses two pieces of software under the hood
  * [z3](https://github.com/Z3Prover/z3)
  * [boogie](https://github.com/boogie-org/boogie)
* Boogie is a tool from Microsoft, so obviously it needs dotnet
  * good news is that it works with .NET Core, so you can install it on *NIX systems!
* If you are on Mac like me then the process is as follows (works on M1!):
  * `brew install z3`
  * `brew install dotnet-sdk`
    * make sure you have `dotnet-sdk` installed, not `dotnet`, otherwise boogie will abort with errors
  * `dotnet tool install --global boogie`
    * this will print out instructions on how to add `boogie` to your `PATH`
    * follow them and restart your shell
  * prover seems to have problems finding tools in `PATH`
    * it uses `BOOGIE_EXE` and `Z3_EXE` shell variables to find it
    * so you will need two lines added to your profile file (`.zshenv`, `.zprofile`, maybe `.bashrc`):
      ```
      export BOOGIE_EXE=`which boogie`
      export Z3_EXE=`which z3`
      ```

## Running

If you have everything set up then you can run prover with `aptos move prove` in your package directory.

## Reading

I decided to keep this simple and not put too much into this "chapter" as there is already a lot to understand. If you managed to install and run prover then you can go through a contract with specification embedded:

* `Counter.move` (./sources/Counter.move)

You will find most of the constructs available in [Move Specification Language doc](https://github.com/move-language/move/blob/main/language/move-prover/doc/user/spec-lang.md).

