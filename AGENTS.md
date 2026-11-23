# Agent instructions

## Workspace and local context

- Treat this repository as a self-contained macOS project. Keep `kch` as a
  single Zsh script with macOS tools as its only runtime dependencies.
- Open the project with `kch.code-workspace`. It includes the source folder and
  the local `kch docs` side-directory from the second brain.
- Consult the `_kch.md` project anchor in `kch docs` first, then any relevant
  local documents, before making design changes. If the workspace or required
  documents cannot be verified or accessed, ask before proceeding.
- Keep the local workspace file and second-brain documents out of source
  control. Use `kch.code-workspace.example` as the shareable workspace
  reference.
- Preserve unrelated work in the working tree and keep changes focused.

## Documentation

- Put finalized user-facing behavior and contributor guidance in `README.md` or
  `CONTRIBUTING.md` as appropriate.
- Update inline help and `README.md` when command behavior or options change.

## Branches and releases

- Before creating a commit, work on a dedicated branch rather than the
  default branch, unless explicitly requested otherwise.
- Name branches `<type>/<short-kebab-case-description>`, using an appropriate
  prefix such as `feat/`, `fix/`, `docs/`, `refactor/`, `test/`, `chore/`, or
  `release/`.
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

## Implementation and verification

- Follow the existing CLI parsing, error-reporting, and completion patterns.
- Do not silently change existing command behavior or compatibility. Add or
  update tests for behavior changes.
- Preserve explicit error reporting and avoid printing secret values. Document
  security-relevant limitations and exposure risks honestly.
- Use synthetic values only. Never put real passwords, tokens, private keys, or
  other secrets in tests, fixtures, logs, examples, or documentation.
- Run `zsh tests/test-cli.zsh` for CLI changes and
  `zsh tests/test-integration.zsh` for Keychain behavior changes. The
  integration test must use its isolated temporary keychain; never test
  against or modify the user's default keychain.
- Do not add runtime dependencies or broaden the project beyond the requested
  change.
