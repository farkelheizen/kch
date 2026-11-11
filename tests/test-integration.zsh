#!/bin/zsh
setopt errexit nounset pipefail

root=${0:A:h:h}
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/kch-test.XXXXXXXX")
export KCH_TEST_KEYCHAIN="$tmpdir/test.keychain-db"
cleanup() {
  /usr/bin/security delete-keychain "$KCH_TEST_KEYCHAIN" >/dev/null 2>&1 || true
  rm -f "$tmpdir/security" "$tmpdir/pbcopy" "$tmpdir/cat" "$tmpdir/kch" "$tmpdir/clipboard" "$tmpdir/value" "$tmpdir/output" "$tmpdir/names"
  rmdir "$tmpdir"
}
trap cleanup EXIT

/usr/bin/security create-keychain -p temporary-test-password "$KCH_TEST_KEYCHAIN"
/usr/bin/security unlock-keychain -p temporary-test-password "$KCH_TEST_KEYCHAIN"

cat > "$tmpdir/security" <<'EOF'
#!/bin/zsh
if [[ $1 == default-keychain ]]; then
  print -r -- "\"$KCH_TEST_KEYCHAIN\""
elif [[ ${KCH_TEST_FAIL_FIND-} == 1 && $1 == find-generic-password ]]; then
  print -u2 'synthetic failure'
  exit 51
else
  exec /usr/bin/security "$@"
fi
EOF
cat > "$tmpdir/pbcopy" <<'EOF'
#!/bin/zsh
[[ ${KCH_TEST_FAIL_CLIP-} == 1 ]] && exit 1
cat > "${KCH_TEST_KEYCHAIN:h}/clipboard"
EOF
cat > "$tmpdir/cat" <<'EOF'
#!/bin/zsh
if [[ ${KCH_TEST_FAIL_CAT-} == 1 ]]; then
  print -rn -- 'partial input'
  exit 1
fi
exec /bin/cat "$@"
EOF
chmod +x "$tmpdir/security" "$tmpdir/pbcopy" "$tmpdir/cat"
ln -s "$root/kch" "$tmpdir/kch"
export PATH="$tmpdir:$PATH"
cli="$root/kch"

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    print -u2 -r -- "Expected failure: $*"
    exit 1
  fi
}

printf 'line one\nline two\n\n' > "$tmpdir/value"
"$cli" add SECRET < "$tmpdir/value"
"$cli" get SECRET > "$tmpdir/output"
printf 'line one\nline two\n\n\n' | cmp -s - "$tmpdir/output"
"$cli" copy SECRET
cmp -s "$tmpdir/value" "$tmpdir/clipboard"
expect_failure env KCH_TEST_FAIL_CLIP=1 "$cli" copy SECRET
expect_failure "$cli" add SECRET
printf 'new-value' | "$cli" update SECRET
[[ $("$cli" get SECRET) == new-value ]]
expect_failure "$cli" update MISSING
expect_failure "$cli" update SECRET < "$tmpdir"
[[ $("$cli" get SECRET) == new-value ]]
expect_failure "$cli" add UNREADABLE < "$tmpdir"
expect_failure "$cli" get UNREADABLE
expect_failure env KCH_TEST_FAIL_CAT=1 "$cli" update SECRET < "$tmpdir/value"
[[ $("$cli" get SECRET) == new-value ]]
expect_failure env KCH_TEST_FAIL_CAT=1 "$cli" add PARTIAL < "$tmpdir/value"
expect_failure "$cli" get PARTIAL

printf 'namespace-secret' | "$cli" --namespace dev_secrets add API_KEY
[[ $(/usr/bin/security find-generic-password -s dev_secrets -a API_KEY -w "$KCH_TEST_KEYCHAIN") == namespace-secret ]]
[[ $("$cli" --namespace dev_secrets list -i api) == API_KEY ]]
printf 'other' | "$cli" --account other add other-secret
[[ $("$cli" --account other list) == other-secret ]]
[[ $("$cli" list -i secret) == SECRET ]]
[[ -z $("$cli" list '[*]') ]]

printf '' | "$cli" add EMPTY
"$cli" copy EMPTY
[[ ! -s "$tmpdir/clipboard" ]]
printf 'unicode café \\" %02048d\n\n' 1 > "$tmpdir/value"
"$cli" add LONG < "$tmpdir/value"
"$cli" cp LONG
cmp -s "$tmpdir/value" "$tmpdir/clipboard"
printf 'value' | "$cli" add 'spaces " and $(touch nope)'
"$cli" __complete > "$tmpdir/names"
completion_names=()
while IFS= read -r -d '' item; do completion_names+=("$item"); done < "$tmpdir/names"
expected_name='spaces " and $(touch nope)'
[[ ${completion_names[(Ie)$expected_name]} -gt 0 ]]
[[ $("$cli" list '$(touch') == *'touch'* ]]
zsh -c '
  compdef() { : }
  compadd() { print -r -l -- "$@" }
  eval "$(kch completions)"
  words=(kch get "")
  CURRENT=3
  output=$(_kch)
  [[ $output == *'"'"'spaces " and $(touch nope)'"'"'* ]]
  words=(kch run SECRET -- "")
  CURRENT=5
  [[ -z $(_kch) ]]
'

printf "quote'\$HOME\nlast\n" | "$cli" add COMPLEX
exports=$("$cli" env COMPLEX)
unset COMPLEX
eval "$exports"
[[ $COMPLEX == $'quote\'$HOME\nlast\n' ]]
"$cli" run COMPLEX -- /bin/zsh -c '[[ $COMPLEX == $'"'"'quote\047$HOME\nlast\n'"'"' ]]'
for name in RANDOM UID values assignments run_command argv status; do
  printf 'secret-for-%s' "$name" | "$cli" add "$name"
done
printf '/usr/bin:/bin' | "$cli" add PATH
"$cli" run RANDOM UID values assignments run_command argv status PATH -- /usr/bin/env > "$tmpdir/output"
for name in RANDOM UID values assignments run_command argv status; do
  grep -Fxq "$name=secret-for-$name" "$tmpdir/output"
done
grep -Fxq 'PATH=/usr/bin:/bin' "$tmpdir/output"
if "$cli" run COMPLEX -- /bin/zsh -c 'exit 37'; then
  print -u2 'run failed to propagate child status'
  exit 1
else
  [[ $? == 37 ]]
fi
expect_failure "$cli" run COMPLEX MISSING -- touch "$tmpdir/should-not-exist"
[[ ! -e "$tmpdir/should-not-exist" ]]
expect_failure "$cli" env COMPLEX MISSING
if "$cli" env COMPLEX MISSING > "$tmpdir/output" 2>/dev/null; then exit 1; fi
[[ ! -s "$tmpdir/output" ]]
expect_failure "$cli" env 'NOT-VALID'
expect_failure "$cli" --account other --namespace app list
expect_failure env KCH_TEST_FAIL_FIND=1 "$cli" add FAILURE
printf 'a\0b' > "$tmpdir/value"
expect_failure "$cli" add NUL < "$tmpdir/value"

"$cli" delete SECRET >/dev/null
expect_failure "$cli" get SECRET
expect_failure "$cli" delete SECRET
print 'Integration tests passed.'
