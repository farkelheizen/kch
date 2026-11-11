# Project instructions

## Project shape

- Keep `kch` a self-contained Zsh script with macOS tools as its only runtime
  dependencies.
- Follow the existing CLI parsing, error-reporting, and completion patterns.
  Update inline help and `README.md` when command behavior or options change.
- Keep changes focused. Do not silently change existing command behavior or
  compatibility; add or update tests for behavior changes.

## Versioning and releases

- Use Semantic Versioning (`MAJOR.MINOR.PATCH`) for releases: patch for
  backward-compatible fixes, minor for backward-compatible features, and
  major for incompatible CLI changes.
- Before `1.0.0`, minor releases may also contain incompatible CLI changes;
  document them clearly. Apply the compatibility guarantees above starting
  with `1.0.0`.
- Keep the authoritative version in `kch` and expose it with `kch --version`.
  When cutting a release, make the version reported by the script match the
  Git tag `vMAJOR.MINOR.PATCH`.
- Do not bump the release version or create a release tag for ordinary
  unreleased changes.
- Before tagging, run the relevant checks, review user-facing documentation,
  and ensure the release notes accurately describe compatibility and security
  implications.

## Plans and documentation

- Put substantial or design-dependent work plans in the ignored `docs_local/`
  directory. Use a focused filename such as `feature-name-plan.md`; record
  decisions, proposed behavior, implementation steps, and validation.
- Use `docs_local/` for planning, not as a substitute for durable project
  documentation. Move finalized user-facing behavior and contributor guidance
  into `README.md` or `CONTRIBUTING.md` as appropriate.
- Treat local plans as private working material: do not stage or commit them,
  and never put secrets or sensitive user data in them.

## Validation and safety

- Run `zsh tests/test-cli.zsh` for CLI changes and
  `zsh tests/test-integration.zsh` for Keychain behavior changes. The
  integration test must use its isolated temporary keychain; never test
  against or modify the user's default keychain.
- Use synthetic values only. Never put real passwords, tokens, private keys,
  or other secrets in tests, fixtures, logs, examples, or documentation.
- Preserve explicit error reporting and avoid printing secret values. Document
  security-relevant limitations and exposure risks honestly.
- Do not add runtime dependencies or broaden the project beyond the requested
  change.
