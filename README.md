# kch

`kch` is a small macOS CLI for generic passwords in Keychain. It wraps Apple's
`security` command and adds convenient listing, namespace selection, clipboard
support, and process-scoped secret injection. The runtime is one Zsh script
using commands included with macOS; there are no packages to install.

Created by [Bill Spratley](https://github.com/farkelheizen).

## Install

Clone the [repository](https://github.com/farkelheizen/kch) and change into
its directory:

```zsh
git clone https://github.com/farkelheizen/kch.git
cd kch
```

Check `command -v kch` for an existing command, then install for your user:

```zsh
mkdir -p "$HOME/.local/bin"
cp -i kch "$HOME/.local/bin/kch"
chmod +x "$HOME/.local/bin/kch"
```

If you decline the overwrite prompt, do not run `chmod` on the existing file.
If `~/.local/bin` is not on your `PATH`, add this to `~/.zshrc`, then open a
new terminal or run `source ~/.zshrc`:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Run `kch help` to verify installation. To update, obtain the newer script and
repeat the copy and permission steps. To uninstall, remove
`~/.local/bin/kch`; stored passwords are not deleted.

## Versioning

Run `kch --version` (or `kch -V`) to see the version of the installed script.
The version is maintained in the script. Releases follow Semantic Versioning
(`MAJOR.MINOR.PATCH`) and use a matching Git tag, such as `v1.2.3`. A major
release may include incompatible CLI changes; minor releases add
backward-compatible features, and patch releases contain
backward-compatible fixes.

## Commands

```zsh
kch --version
kch add API_KEY             # Interactive password prompt
kch update API_KEY          # Requires an existing item
kch get API_KEY             # Print secret, followed by one newline
kch list                    # List names for the current account
kch list API                # Literal, case-sensitive substring
kch list -i api             # Case-insensitive substring
kch copy API_KEY            # Copy without printing; cp is an alias
kch delete API_KEY          # Delete immediately, without confirmation
kch open                    # Open Keychain Access
kch help
```

Quote names containing spaces. List output uses Zsh shell quoting. A list
with no matches prints nothing and succeeds. Add fails for duplicates; update,
get, copy and delete fail if the item is missing.

To supply a secret via stdin, including multiple lines and trailing newlines:

```zsh
kch add PRIVATE_KEY < private-key.pem
```

**Piped input is passed to `security` as a process argument.** Other processes
with sufficient access may observe it, and `kch` prints a warning. Interactive
input instead uses the native `security` prompt without putting the secret in
arguments. Input cannot contain NUL bytes; empty input is supported. Input is
limited by the OS command-line size limit. A failed input read aborts without
writing the item. `get` adds one newline; use `copy` to copy the exact stored
text without that extra newline.

## Accounts and namespaces

By default, the service is the supplied name and the account is `$USER`, as
in the original script. Existing entries remain accessible. Options must come
before the command:

```zsh
kch --account another-user get API_KEY
kch --namespace dev_secrets add API_KEY
kch --namespace dev_secrets list -i api
```

`--namespace` uses the namespace as the service and the supplied name as the
account. For example, an item created above can be read with Python keyring's
`keyring.get_password("dev_secrets", "API_KEY")` when it uses the same macOS
keychain. `--account` and `--namespace` cannot be combined. Namespace mode
does not migrate existing items.

Default listing includes _all_ generic-password services with the selected
account, including items created by other applications. Namespace listing
includes all generic-password accounts with that service. Neither is limited
to items created by `kch`.

## Environment and child processes

Bare names supplied to `env` and `run` must be valid shell environment-variable
names. To use a different Keychain name, map the destination explicitly:

```zsh
kch env API_KEY --map DB_PASSWORD=DATABASE:password
kch run --map MYAPP_KEY1=MYAPP.KEY1 API_KEY -- python app.py
```

Mappings split at the first `=`. Destinations must be valid ASCII environment
variable names and must not be repeated. All selections are checked and
retrieved before any exports are printed or the child starts.

For each secret, `--normalize` replaces every dot or colon with an underscore;
`--strip-prefix` removes the part through the first dot or colon:

```zsh
kch run --normalize MYAPP.KEY1 --strip-prefix OTHER:KEY2 \
  --map MANUAL=THIRD.secret PLAIN_KEY -- python app.py
```

These produce `MYAPP_KEY1`, `KEY2`, `MANUAL`, and `PLAIN_KEY`. Transformations
preserve case. Prefix stripping requires a nonempty prefix and suffix, and
neither form changes any other characters. Invalid destinations (such as
`SUB.KEY` from `--strip-prefix APP.SUB.KEY`) and collisions between selections
are rejected. Use `--map` when an automatic transformation isn't suitable.

`run` then replaces itself with the command:

```zsh
kch run API_KEY DB_PASSWORD -- python app.py
```

Only the child and its descendants inherit these variables, not the current
interactive shell. Environment variables can still be inspected by authorized
processes and are inherited by child processes. If a selection sets `PATH`,
`run` uses that value to locate an unqualified command as well as passing it
to the child. Use an absolute command path to bypass `PATH` lookup. `run`
executes external programs, not shell builtins; use `zsh -c` explicitly if a
builtin is needed. It rejects `_` and `SHLVL` as destinations because Zsh
replaces those environment variables when starting a command.

`env` prints shell-quoted `export` statements containing plaintext. Check
success before evaluating trusted output. Because assignments to Zsh special
parameters such as `RANDOM`, `UID`, and `PATH` can change the value or shell
behavior, `env` rejects those destinations. Map them to ordinary variable
names or use `run`, which supports them in the child environment. Other
pre-existing readonly or specially typed variables in the evaluating shell
can also prevent an export; choose a different destination in that case.

```zsh
if exports="$(kch env API_KEY DB_PASSWORD)"; then
  eval "$exports"
  unset exports
else
  echo "Could not load secrets" >&2
fi
```

The same pattern can be used in a `.envrc` with direnv, if installed. Avoid
logging the output or placing it in version control. Exporting into your
current shell keeps values available to subsequent child processes.

## Zsh completion

After `compinit`, add the following to `~/.zshrc`:

```zsh
eval "$(kch completions)"
```

Completion looks up names from Keychain metadata. Names may be visible on
screen and in shell history.

## Security and limitations

- Operations target the macOS default keychain (`security default-keychain`),
  normally the login keychain, not the whole search list or iCloud Keychain.
  Installing on another Mac does not synchronize secrets.
- macOS may request Keychain unlock or access authorization. `kch` does not
  enable unrestricted application access.
- `get`, `env`, environment variables, and clipboard contents can expose
  secrets. Clipboard managers may retain copied values; `kch` does not clear
  the clipboard automatically. Avoid putting secrets in logs or shell history.
- Names and other metadata are not secret. `list` reads metadata, not passwords.
- Because `security -U` is an upsert, another process deleting an item between
  the update existence check and write can cause an update to recreate it.
  Likewise, a concurrent default-keychain change can affect interactive writes.
- Passwords containing NUL bytes are unsupported. Other binary data is not a
  supported interface; use text. `security` may impose additional limits.

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests and [SECURITY.md](SECURITY.md)
for vulnerability reporting.

## License

Copyright 2026 William Spratley. Licensed under the
[Apache License, Version 2.0](LICENSE).
