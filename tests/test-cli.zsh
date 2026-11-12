#!/bin/zsh
setopt errexit nounset pipefail
root=${0:A:h:h}
cli="$root/kch"
for file in "$cli" "$root/tests/test-cli.zsh" "$root/tests/test-integration.zsh"; do
  zsh -n "$file"
done
if grep -nE '[[:blank:]]+$' "$cli" "$root/tests/test-cli.zsh" "$root/tests/test-integration.zsh"; then
  print -u2 'Trailing whitespace found'
  exit 1
fi
"$cli" help | grep -q 'Usage: kch'
"$cli" help | grep -q -- '--version'
[[ $("$cli" --version) == 'kch 0.2.0' ]]
[[ $("$cli" -V) == 'kch 0.2.0' ]]
if "$cli" --version unexpected >/dev/null 2>&1; then
  print -u2 '--version unexpectedly accepted extra arguments'
  exit 1
fi
"$cli" completions | grep -q 'compdef _kch kch'
"$cli" completions | grep -q -- '--version -V'
"$cli" help | grep -q 'put NAME'
"$cli" completions | grep -q 'add update put delete'
if "$cli" nonexistent >/dev/null 2>&1; then
  print -u2 'Unknown command unexpectedly succeeded'
  exit 1
fi
if "$cli" run NAME >/dev/null 2>&1; then
  print -u2 'Invalid run unexpectedly succeeded'
  exit 1
fi
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/kch-install.XXXXXXXX")
cleanup() {
  rm -f "$tmpdir/.local/bin/kch"
  rmdir "$tmpdir/.local/bin" "$tmpdir/.local" "$tmpdir"
}
trap cleanup EXIT
mkdir -p "$tmpdir/.local/bin"
cp -i "$cli" "$tmpdir/.local/bin/kch"
chmod +x "$tmpdir/.local/bin/kch"
HOME="$tmpdir" PATH="$tmpdir/.local/bin:$PATH" kch help | grep -q 'Usage: kch'
print 'CLI checks passed.'
