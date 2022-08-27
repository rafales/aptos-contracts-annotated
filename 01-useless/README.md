# `01-useless`

So this useless contract allows you to do one thing - introduce yourself.

1. It introduces a `Passport` struct which holds nothing but your name.
2. If you decide to call `say_my_name` from an account - it will store your name inside `Passport` structure in your own account's storage.
3. You can change your name at any time.
4. It is utterly useless.
5. It doesn't showcase many of the Move's capabilities. It's just basics so I can deploy anything.

## Setting up

1. Run `aptos init` in project directory
  - it will ask you for private key, endpoints etc
  - it will create `.aptos` directory containing this information
2. If you are using my code you may want to update addresses in `Move.toml`

## Reading

You can read the annotated sources in the following order:

- [Move.toml](./Move.toml)
- [Useless.move](./sources/Useless.move)

## Publishing

Publishing module is as simple as:

```
aptos move publish
```

## Interacting with contract

Sadly this one doesn't read named addresses from `Move.toml` at the moment so you need to provide full address by hand:

```
aptos move run --function-id 4348f2118192eb9db970a108acf6713bcd5e527e0687a53454abc74864b20d83::Useless::say_your_name --args string:john
```

## Reading resources via REST API

Now we can confirm if the resource was created properly:

```
httpx https://fullnode.devnet.aptoslabs.com/v1/accounts/4348f2118192eb9db970a108acf6713bcd5e527e0687a53454abc74864b20d83/resources
```

1. You can use `curl` instead of `httpx` if you don't have it.
2. I'm using the same account for contract deployment and interaction, but it's completely valid to call `say_my_name` with different account - it should create resources in it as well.
