# [WORK IN PROGRESS] `06-tables`

`Aptos` has another feature which comes in handy when you need to create large mappings. But it's easy to confuse it with a simple mapping type. `Aptos` provides us with both, so let's see what the differences are.

## `aptos_std::SimpleMap` vs `aptos_std::Table`

So let's take a look at both of them. On the surface you can treat them as mappings:

```move
use aptos_std::simple_map::{Self, SimpleMap};
use aptos_std::table::{Self, Table};
use std::string::String;

fun hello() {
    let sm: SimpleMap<String, u64> = simple_map::create();
    let tbl: Table<String, u64> = table::new();
    
    table::add(&mut tbl, string::utf8(b"test"), 123);
    simple_map::add(&mut sm, string::utf8(b"test"), 123);
}
```

You can:

* check if key is available in the mapping
* borrow values
* remove items
* and some other operations

So what's the difference? Implementation.

### Simple Maps

* implemented under the hood in `Move` itself using a `vector` 
   ```move
   struct SimpleMap<Key, Value> has copy, drop, store {
     data: vector<Element<Key, Value>>,
   }
   ```
* all data is kept in the struct, so locally
* they are not that useful for keeping large amounts of data
* can be easily destroyed when empty

### Tables

* implemented in `Rust` (so on the native side)
   ```move
   struct Table<phantom K: copy + drop, phantom V> has store {
     handle: address,
   }
   ```
  * all you keep in your `struct` is basically a "reference" (in form of an `address`) to the table
* you can't remove a table, so you need to be careful with it!
  * you can use `TableWithLength` which can be removed when empty
* suitable for storage of large amounts of entries
* has special REST APIs to access data in tables as they don't live in accounts

## Different flavours of tables

Move comes with different types of tables:

* `aptos_std::table`
  * most basic kind of table
  * most similar to mapping from `Solidity`
  * you don't know amount of keys stored, you don't know the keys themselves
  * because you don't know if it's empty or what the keys are - it can't be removed after it is created
* `aptos_std::table_with_length`
  * provides two additional features:
    * it keeps track of the amount of keys a mapping has
    * because it knows the length - you can drop if it's empty
* `aptos_std::iterable_table`
  * builds upon `TableWithLength`
  * but additionally uses a linked list pattern to make it possible to iterate over items
* `aptos_std::bucket_table`
  * it's an alternative for `table_with_length` that is optimized for storage
  * it can have lower performance though
  * you probably shouldn't use it unless you know exactly what you are doing

## REST APIs

Usually you would look up data in an account via the account resources endpoint. But with tables you can use it only to retrieve table's handle (which is of type `address`).

To retrieve items from a table you will use a separate ["Get table item"](https://fullnode.devnet.aptoslabs.com/v1/spec#/operations/get_table_item) endpoint, which expects table key. You will also need to provide value and key type.
