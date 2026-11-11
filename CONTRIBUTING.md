# Contributing

Run these checks on macOS with Zsh and the built-in `security` command:

```zsh
zsh tests/test-cli.zsh
zsh tests/test-integration.zsh
```

The CLI checks include Zsh syntax and trailing-whitespace lint. The integration
test creates and deletes a temporary keychain and uses only
synthetic passwords. Never add real secrets to tests, fixtures, logs, or issues.
The CLI must remain a single script with no non-macOS runtime dependencies.

There is currently no selected project license. Confirm the owner's licensing
and contribution terms before submitting or redistributing changes.
