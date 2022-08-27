# Aptos Annotated Contracts

So I began to learn Move. It's an interesting language and a totally different concept than Solidity/EVM.
Because Move and Aptos are pretty niche at the moment and there aren't many resources to learn - I'm publishing the code I'm writing as I learn - with annotations. Maybe they'll be of some use to you.

## How to start with Aptos and Move

So my road was pretty simple. You will need development experience though.

1. Read [the whitepaper](https://aptos.dev/aptos-white-paper/aptos-white-paper-index)
2. Get Aptos wallet and set it up
   - you will need a private key later
   - you will also need some coins which you can easily get from wallet UI
3. Install CLI locally
   - this may be pain
   - **DON'T** start with [Getting Started](https://aptos.dev/guides/getting-started) guide, instead follow [CLI installation guide](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli)
   - if you are developing on `devnet` (you probably are), make sure you pass `--branch devnet` when installing CLI wih cargo.
4. If you're using JetBrains IDEs then install [Move Plugin](https://plugins.jetbrains.com/plugin/14721-move-language) **AND CONFIGURE IT** in settings before use.
5. Read the [Move Book](https://move-book.com).
   - personally I didn't start developing before I've read the whole book to understand what's happening. There aren't many good sources out there yet that will guide you step by step, so it's good to get an overview of what we're dealing with.
   - I also wasn't able to run any examples until later down the path LOL
6. At this point you can start building, but you don't have to yet.
   - you can take a look at first `useless` module to see how packages look like and what minimal working setup looks like
   - you can continue to the Move Language Guide
   - you can read the step-by-step articles below, but some of them are a bit outdated and do not depend on the CLI yet
7. Read [Move Language Guide](https://move-language.github.io/move/) - which is also named "Move Book" for some reason. This will fill in a lot of blanks.
8. At this point you should realize that Aptos provides a lot of libraries - `std`, `aptos_std`, `aptos_framework` inside `AptosFramework`
   - you should read them to start getting better understanding of what aptos provides and how Move codebase looks like
   - if you are using JetBrains IDEs then you can find their sources under "External Libraries" in Project Panel
   - otherwise you can browse its [source code](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/framework) directly on GitHub.
9. You can read through these series (there may be more now, so check author's page):
   - [Aptos Tutorial Episode 1: Create Things](https://medium.com/@magnum6/replay-aptos-tutorial-episode-1-create-things-90920fcdf409)
   - [Aptos Tutorial Episode 2: Sell Things](https://medium.com/code-community-command/were-picking-up-where-we-left-off-at-the-last-episode-so-if-this-is-your-first-time-here-check-394ddb8950f0)
   - [Aptos Tutorial Episode 3: Deploy Things (and, boy, did those things just get easier)](https://medium.com/code-community-command/aptos-tutorial-episode-3-deploy-things-94eb973a7a51)
   - [Aptos Tutorial Episode 4: Let’s Table This For Now (Part 1)](https://medium.com/code-community-command/aptos-tutorial-episode-4-lets-table-this-for-now-part-1-2e465707f83d)
