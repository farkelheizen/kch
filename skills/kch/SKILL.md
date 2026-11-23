---
name: kch
description: Use the kch macOS Keychain CLI to manage generic passwords or provide secrets to a child process. Use when a user asks about kch, its namespaces, or running a command with Keychain-backed environment variables.
license: Apache-2.0
compatibility: Requires macOS, Zsh, the macOS security command, and an installed kch CLI.
---

# Using kch

Use this skill for the user's kch tasks, not as permission to access their
Keychain. Follow the agent's own approval and security rules.

## Safety

- Never put real secrets in prompts, command arguments, logs, files, shell
  history, or agent-visible output. Do not run `kch get` or `kch env` through
  an agent tool that captures output: both print plaintext. Do not enable
  shell tracing around secret operations.
- Ask for permission before accessing Keychain metadata or secrets, changing
  items, copying to the clipboard, or starting a process with secrets. Confirm
  the target and operation; confirm especially before overwrite or deletion.
  `delete` has no confirmation and `put` replaces existing passwords.
- For adding or changing secrets, have the user run `kch add`, `kch update`,
  or `kch put` interactively in their own terminal using the native prompt.
  Do not request the secret in chat. Piped input is passed to `security` as a
  process argument and may be observable.
- Prefer `kch run` to supply secrets directly to an approved, trusted child
  process. This does not make the child safe: it can print or transmit
  secrets, and environment variables can be inspected by authorized processes
  and inherited by descendants. Check the command and its output handling
  before running it; if secrecy cannot be maintained, have the user run it
  privately.
- `copy` exposes the value to the clipboard and potentially clipboard
  managers; kch does not clear it automatically. Names and other metadata may
  also be sensitive to the user.

## Workflow

1. Check that `kch` is available with `command -v kch`, then use
   `kch --version` and `kch help` to check the installed interface. If it is
   unavailable, explain the prerequisite rather than installing it silently.
2. Identify the exact operation, item name, account or namespace, and any
   destination environment variable. Ask the user when these are unclear.
   Options such as `--account` and `--namespace` must precede the command.
3. Use only the approved operation. Quote names containing spaces. Report
   errors without exposing secrets and do not silently retry with a different
   account, namespace, or Keychain.

By default, the name is the generic-password service and `$USER` is the
account. `--account` changes the account. With `--namespace SERVICE`, SERVICE
is the service and the supplied name is the account; the two options cannot be
combined. Operations target the macOS default keychain, and macOS may prompt
for access.

`list` reads metadata, not passwords. It can include items created by other
applications; an empty result succeeds. `add` fails for an existing item,
`update` fails for a missing item, and `put` is an upsert.

For an approved child command, a typical shape is:

```zsh
kch run --map ENV_NAME=KEYCHAIN_NAME -- /absolute/path/to/trusted-program
```

Replace the placeholders with the approved item, destination, and command.
`run` accepts bare names that are valid environment variable names, or
`--map ENV_NAME=KEYCHAIN_NAME` for an explicit mapping. `--normalize` replaces
dots and colons with underscores; `--strip-prefix` removes through the first
dot or colon. Invalid or duplicate destinations fail. The `--` separates
selections from the external command; use an absolute command path to avoid
`PATH` lookup. `run` does not execute shell builtins directly.

For full behavior and limitations, consult the installed `kch help` and the
[project documentation](https://github.com/farkelheizen/kch#readme). The
installed version may differ from the latest documentation. Do not assume a
skill instruction grants permission to override host restrictions.
