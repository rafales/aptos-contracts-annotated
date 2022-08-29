"""
This is a helper for interacting with my coin, so I can better understand
the flow and the differences between ERC-20.
"""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from itertools import chain
from pathlib import Path
from typing import Optional, Any

import rich
import typer
import typer as t
import yaml
from aptos_sdk import transactions as bcs
from aptos_sdk.account import Account
from aptos_sdk.client import FaucetClient, RestClient
from rich.table import Table
from toolz import get_in

# Typer is super nifty utility for creating CLI.
# It's huge selling point is that it uses type hints/typing information
# instead of relying on dev to configure everything.
from typing_extensions import Self

app = t.Typer()
console = rich.get_console()


def find_config_dir(start: Path, cfg_name: str | Path) -> Optional[Path]:
    """
    Utility for looking for a given file/directory in parent directories.

    Useful when you want to find .env file in `start` or it's parent directories.
    """
    for d in chain((start,), start.parents):
        needle = d / cfg_name
        if needle.exists():
            return needle


def find_move_pkg() -> Optional[Path]:
    """
    Finds the closest parent directory with `Move.toml` in it.

    Returns path to the `Move.toml` file.
    """
    return find_config_dir(Path.cwd(), "Move.toml")


def find_aptos_dir() -> Optional[Path]:
    """
    Traverses directories upwards and looks for ".aptos" directory.

    This directory is where Aptos CLI stores information like private keys,
    fullnode endpoint or faucet endpoint.

    So instead of having to provide this info twice we will simply read it from
    aptos config.
    """
    return find_config_dir(Path.cwd(), ".aptos")


def get_aptos_profile_config(
    aptos_dir: Path, profile_name: str = "default"
) -> Optional[dict[str, Any]]:
    """
    Reads configuration (private keys, full node url etc) from Aptos CLI config.

    Aptos CLI supports multiple profiles, with the default named 'default'.

    :param aptos_dir: '.aptos' directory obtained by calling `find_aptos_dir`.
    :param profile_name: profile name to get config for
    """
    with (aptos_dir / "config.yaml").open() as fp:
        all_config = yaml.safe_load(fp)

    cfg = get_in(["profiles", profile_name], all_config)
    assert cfg is None or isinstance(
        cfg, dict
    ), "Loaded aptos profile information but it wasn't an object/dictionary"
    return cfg


@app.callback()
def app_callback(ctx: t.Context, profile: str = "default"):
    # Callback in 'typer' is basically a setup function which can have its
    # own additional arguments (so 'profile' above becomes '--profile' param).

    try:
        ctx.obj = AppObject.create(profile=profile)
    except SdkDirNotFound:
        raise t.BadParameter(
            "Could not find .aptos directory. Please use 'aptos init' first."
        )
    except ProfileNotFound:
        raise t.BadParameter(
            f"Profile with name '{profile}' does not exist or is empty."
        )


class SdkDirNotFound(Exception):
    pass


class ProfileNotFound(Exception):
    pass


class AccountAlreadyExists(Exception):
    pass


@dataclass
class AppObject:
    """
    Our "world object" which implements core logic and keeps most important object instances.
    """

    # Rest Client from Aptos SDK
    client: RestClient
    # Faucet Client from Aptos SDK
    faucet: FaucetClient
    # "root" account, specified in aptos, where the contract code is stored
    root: Account
    # .aptos SDK directory
    # we will keep our generated private keys there
    aptos_dir: Path
    # name of the profile we are using
    profile_name: str

    @classmethod
    def create(cls, *, profile: str) -> Self:
        # First we'll read profile information from Aptos CLI (so information like private key or
        # full-node url). This is done for convenience so that I don't have to specify things twice.
        if not (aptos_dir := find_aptos_dir()):
            raise SdkDirNotFound()

        if not (cfg := get_aptos_profile_config(aptos_dir, profile)):
            raise ProfileNotFound()

        client = RestClient(cfg["rest_url"].rstrip("/"))
        faucet = FaucetClient(cfg["faucet_url"].rstrip("/"), client)

        return AppObject(
            client=client,
            faucet=faucet,
            root=Account.load_key(cfg["private_key"]),
            aptos_dir=aptos_dir,
            profile_name=profile,
        )

    @property
    def _keys_dir(self) -> Path:
        return self.aptos_dir / "keys" / self.profile_name

    def create_account(self, name: str, *, fund_amount: int = 0) -> Account:
        """
        Creates new account and remembers it.
        """
        # 'root' is reserved for the key we acquired from Aptos SDK
        assert name != "root", "name 'root' is reserved"
        # we will keep keys in a json file in Aptos SDK's config directory
        key_path = self._keys_dir / f"{name}.json"
        if key_path.exists():
            raise AccountAlreadyExists()

        acc = Account.generate()
        # we need to create account on the blockchain first

        create_acc_payload = {
            "type": "entry_function_payload",
            "function": "0x01::aptos_account::create_account",
            "arguments": [str(acc.address())],
            "type_arguments": [],
        }

        with console.status("Creating account ..."):
            tx_hash = self.client.submit_transaction(self.root, create_acc_payload)
            self.client.wait_for_transaction(tx_hash)

        if fund_amount > 0:
            with console.status("Funding account ..."):
                self.faucet.fund_account(str(acc.address()), fund_amount)

        self._keys_dir.mkdir(parents=True, exist_ok=True)
        acc.store(key_path)

        return acc

    def get_account(self, name: str) -> Optional[Account]:
        """
        Returns account with given name.
        """
        if name == "root":
            return self.root

        key_path = self._keys_dir / f"{name}.json"
        if key_path.exists():
            return Account.load(key_path)

        return None

    def load_accounts(self) -> dict[str, Account]:
        """
        Loads all accounts.
        """
        result = {"root": self.root}

        if self._keys_dir.exists():
            for key_file in self._keys_dir.glob("*.json"):
                name = key_file.stem
                acc = Account.load(key_file)
                result[name] = acc

        return result


@app.command()
def mint(
    ctx: t.Context,
    amount: int,
    to: str = typer.Argument(..., help="Name of the account to mint to"),
) -> None:
    """
    Mints new tokens.
    """
    # TODO ensure 'to' is a valid address
    app = ctx.find_object(AppObject)
    to_acc = app.get_account(to)
    if to_acc is None:
        raise t.BadParameter(f"Account '{to}' not found")

    payload = {
        "type": "entry_function_payload",
        "function": f"{app.root.address()}::MooCoin::mint",
        "arguments": [amount, str(to_acc.address())],
        "type_arguments": [],
    }
    tx_hash = app.client.submit_transaction(app.root, payload)

    with console.status("Waiting for transaction to be mined ..."):
        app.client.wait_for_transaction(tx_hash)


@app.command()
def create_account(
    ctx: t.Context,
    name: str,
    fund: int = t.Option(0, help="Fund wallet with given amount through faucet."),
) -> None:
    app = ctx.find_object(AppObject)
    # we need to use float because typer doesn't support Decimal :| I really need to make a PR
    try:
        acc = app.create_account(name, fund_amount=fund)
    except AccountAlreadyExists:
        raise t.BadParameter("Account with given name already exists")
    console.print(f"{name} :right_arrow: {acc.address()}")


@app.command()
def fund_account(ctx: t.Context, name: str, amount: int) -> None:
    app = ctx.find_object(AppObject)
    account = app.get_account(name)
    if account is None:
        raise t.BadParameter(f"Account with name '{name}' does not exist.")

    app.faucet.fund_account(str(account.address()), amount)


@app.command()
def list_accounts(ctx: t.Context) -> None:
    app = ctx.find_object(AppObject)
    accounts = app.load_accounts()

    def get_balance(a: Account):
        return app.client.account_balance(a.address())

    with ThreadPoolExecutor(max_workers=10) as pool:
        balances = pool.map(get_balance, accounts.values())

    t = Table("Name", "Address", "Balance")
    for (name, acc), balance in zip(accounts.items(), balances):
        t.add_row(name, str(acc.address()), balance)

    console.print(t)


@app.command()
def approve_coin(ctx: t.Context, account_name: str) -> None:
    """
    Approves MooCoin to be used by given account.
    """
    app = ctx.find_object(AppObject)
    acc = app.get_account(account_name)
    if acc is None:
        raise t.BadParameter(f"Account with name '{account_name}' does not exist.")

    fn_call = bcs.ScriptFunction(
        bcs.ModuleId(app.root.address(), "MooCoin"), "register", [], []
    )

    payload = bcs.TransactionPayload(fn_call)
    tx = app.client.create_single_signer_bcs_transaction(acc, payload)

    with console.status("Approving coin ..."):
        tx_hash = app.client.submit_bcs_transaction(tx)
        app.client.wait_for_transaction(tx_hash)


if __name__ == "__main__":
    app()
