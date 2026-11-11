#!/bin/zsh
setopt errexit nounset pipefail

root=${0:A:h:h}
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/kch-test.XXXXXXXX")
export KCH_TEST_KEYCHAIN="$tmpdir/test.keychain-db"
cleanup() {
  /usr/bin/security delete-keychain "$KCH_TEST_KEYCHAIN" >/dev/null 2>&1 || true
  rm -f "$tmpdir/security" "$tmpdir/pbcopy" "$tmpdir/cat" "$tmpdir/kch" "$tmpdir/clipboard" "$tmpdir/value" "$tmpdir/output" "$tmpdir/names" "$tmpdir/pathcmd" "$tmpdir/alternate/pathcmd" "$tmpdir/alternate/export" "$tmpdir/alternate/-v"
  rmdir "$tmpdir/alternate"
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
elif [[ -n ${KCH_TEST_HEX-} && $1 == find-generic-password ]]; then
  print -u2 -r -- "password: 0x${KCH_TEST_HEX}  \"synthetic\""
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
mkdir "$tmpdir/alternate"
cat > "$tmpdir/pathcmd" <<'EOF'
#!/bin/zsh
print -r -- original
EOF
cat > "$tmpdir/alternate/pathcmd" <<'EOF'
#!/bin/zsh
print -r -- "alternate:$PATH:$1"
EOF
cat > "$tmpdir/alternate/export" <<'EOF'
#!/bin/zsh
print -r -- "external:$SECRET"
EOF
cat > "$tmpdir/alternate/-v" <<'EOF'
#!/bin/zsh
print -r -- "dash:$SECRET:$1"
EOF
chmod +x "$tmpdir/pathcmd" "$tmpdir/alternate/pathcmd" "$tmpdir/alternate/export" "$tmpdir/alternate/-v"
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
printf '%s' "$tmpdir/alternate" | "$cli" add ALT_PATH
[[ $("$cli" run --map PATH=ALT_PATH -- pathcmd test) == "alternate:$tmpdir/alternate:test" ]]
[[ $("$cli" run SECRET -- pathcmd) == original ]]
expect_failure "$cli" run PATH -- pathcmd
[[ $("$cli" run PATH -- "$tmpdir/pathcmd") == original ]]
[[ $(cd "$tmpdir" && "$cli" run --map PATH=EMPTY -- pathcmd) == original ]]
[[ $("$cli" run --map PATH=ALT_PATH --map path=SECRET -- pathcmd test) == "alternate:$tmpdir/alternate:test" ]]
[[ $("$cli" run --map PATH=ALT_PATH SECRET -- export) == external:new-value ]]
[[ $("$cli" run --map PATH=ALT_PATH SECRET -- -v argument) == dash:new-value:argument ]]
if "$cli" run PATH SECRET -- export > "$tmpdir/output" 2>/dev/null; then
  print -u2 'run unexpectedly executed a shell builtin'
  exit 1
fi
[[ ! -s "$tmpdir/output" ]]
for name in _ SHLVL; do
  if "$cli" run --map "$name=SECRET" -- /usr/bin/env > "$tmpdir/output" 2>/dev/null; then
    print -u2 -r -- "run unexpectedly accepted the $name environment variable"
    exit 1
  fi
  [[ ! -s "$tmpdir/output" ]]
  expect_failure "$cli" run "$name" -- /usr/bin/env
done
for name in RANDOM UID PATH status; do
  if "$cli" env SECRET "$name" > "$tmpdir/output" 2>/dev/null; then
    print -u2 -r -- "env unexpectedly accepted special parameter: $name"
    exit 1
  fi
  [[ ! -s "$tmpdir/output" ]]
  expect_failure "$cli" env --map "$name=SECRET"
done
[[ $("$cli" env --map ORDINARY=RANDOM) == "export ORDINARY='secret-for-RANDOM'" ]]
printf 'mapped-value' | "$cli" add 'MYAPP.KEY1'
printf 'equal-value' | "$cli" add 'name=with=equals'
"$cli" run SECRET --map RANDOM=MYAPP.KEY1 --map UID=name=with=equals --map values=COMPLEX -- /usr/bin/env > "$tmpdir/output"
grep -Fxq 'SECRET=new-value' "$tmpdir/output"
grep -Fxq 'RANDOM=mapped-value' "$tmpdir/output"
grep -Fxq 'UID=equal-value' "$tmpdir/output"
mapped_exports=$("$cli" env SECRET --map MAPPED=MYAPP.KEY1 --map OTHER=name=with=equals --map QUOTED=COMPLEX)
eval "$mapped_exports"
[[ $SECRET == new-value && $MAPPED == mapped-value && $OTHER == equal-value && $QUOTED == $'quote\'$HOME\nlast\n' ]]
[[ $("$cli" --namespace dev_secrets env --map MY_KEY=API_KEY) == "export MY_KEY='namespace-secret'" ]]
[[ $("$cli" --account other env --map MY_KEY=other-secret) == "export MY_KEY='other'" ]]
"$cli" run --map MY_KEY=MYAPP.KEY1 -- /bin/zsh -c '[[ $MY_KEY == mapped-value && $1 == "--literal" ]]' zsh --literal
expect_failure "$cli" env --map
expect_failure "$cli" env --map invalid
expect_failure "$cli" env --map '=secret'
expect_failure "$cli" env --map 'NAME='
expect_failure "$cli" env --map 'A-B=SECRET'
expect_failure "$cli" env SECRET --map SECRET=MYAPP.KEY1
expect_failure "$cli" env --unknown SECRET
expect_failure "$cli" run --map NAME=SECRET
if "$cli" env SECRET --map ABSENT=MISSING > "$tmpdir/output" 2>/dev/null; then exit 1; fi
[[ ! -s "$tmpdir/output" ]]
expect_failure "$cli" run SECRET --map ABSENT=MISSING -- touch "$tmpdir/should-not-exist"
[[ ! -e "$tmpdir/should-not-exist" ]]
zsh -c '
  compdef() { : }
  compset() { [[ $* == "-P *=" ]]; }
  compadd() { print -r -l -- "$@" }
  eval "$(kch completions)"
  words=(kch run --map "DEST=MY")
  CURRENT=4
  output=$(_kch)
  [[ $output == *MYAPP.KEY1* ]]
  words=(kch run --map DEST)
  [[ -z $(_kch) ]]
'
printf 'normalized-value' | "$cli" add 'My.App:KEY'
printf 'stripped-value' | "$cli" add 'OTHER:KEY2'
printf 'nested-value' | "$cli" add 'A.B.C'
printf 'invalid-start' | "$cli" add '123.VALUE'
printf 'dash-value' | "$cli" add '-app:KEY'
printf 'case-value' | "$cli" add 'app:Key'
"$cli" run --normalize My.App:KEY --strip-prefix OTHER:KEY2 --map MANUAL=MYAPP.KEY1 SECRET -- /usr/bin/env > "$tmpdir/output"
grep -Fxq 'My_App_KEY=normalized-value' "$tmpdir/output"
grep -Fxq 'KEY2=stripped-value' "$tmpdir/output"
grep -Fxq 'MANUAL=mapped-value' "$tmpdir/output"
grep -Fxq 'SECRET=new-value' "$tmpdir/output"
transform_exports=$("$cli" env --normalize My.App:KEY --strip-prefix OTHER:KEY2)
eval "$transform_exports"
[[ $My_App_KEY == normalized-value && $KEY2 == stripped-value ]]
[[ $("$cli" env --strip-prefix '-app:KEY') == "export KEY='dash-value'" ]]
[[ $("$cli" env --normalize 'app:Key') == "export app_Key='case-value'" ]]
[[ $("$cli" --namespace dev_secrets env --normalize API_KEY) == "export API_KEY='namespace-secret'" ]]
printf 'account-value' | "$cli" --account other add 'APP:NAME'
[[ $("$cli" --account other env --strip-prefix APP:NAME) == "export NAME='account-value'" ]]
for selection in '--normalize' '--strip-prefix'; do
  expect_failure "$cli" env "$selection"
  expect_failure "$cli" env "$selection" ''
done
expect_failure "$cli" env --strip-prefix NO_SEPARATOR
expect_failure "$cli" env --strip-prefix ':NAME'
expect_failure "$cli" env --strip-prefix 'APP:'
expect_failure "$cli" env --strip-prefix A.B.C
expect_failure "$cli" env --normalize 123.VALUE
expect_failure "$cli" env --normalize My.App:KEY --map My_App_KEY=SECRET
expect_failure "$cli" env SECRET --strip-prefix 'APP:SECRET'
expect_failure "$cli" env --normalize A.B --normalize A:B
if env KCH_TEST_FAIL_FIND=1 "$cli" env --normalize A.B --map A_B=SECRET > "$tmpdir/output" 2>&1; then exit 1; fi
grep -q 'duplicate environment variable' "$tmpdir/output"
if "$cli" env --normalize My.App:KEY --strip-prefix OTHER:MISSING > "$tmpdir/output" 2>/dev/null; then exit 1; fi
[[ ! -s "$tmpdir/output" ]]
expect_failure "$cli" run --normalize My.App:KEY --strip-prefix OTHER:MISSING -- touch "$tmpdir/should-not-exist"
[[ ! -e "$tmpdir/should-not-exist" ]]
zsh -c '
  compdef() { : }
  compadd() { print -r -l -- "$@" }
  eval "$(kch completions)"
  words=(kch env "")
  CURRENT=3
  output=$(_kch)
  [[ $output == *--normalize* && $output == *--strip-prefix* ]]
  words=(kch env --normalize "")
  CURRENT=4
  output=$(_kch)
  [[ $output == *My.App:KEY* ]]
  words=(kch run --strip-prefix "")
  CURRENT=4
  output=$(_kch)
  [[ $output == *OTHER:KEY2* ]]
  words=(kch run --strip-prefix OTHER:KEY2 -- "")
  CURRENT=6
  [[ -z $(_kch) ]]
'
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

head -c 32768 /dev/zero | tr '\000' '\n' > "$tmpdir/value"
printf 'utf8 café and trailing newlines\n\n' >> "$tmpdir/value"
"$cli" add LARGE_MULTILINE < "$tmpdir/value"
"$cli" copy LARGE_MULTILINE
cmp -s "$tmpdir/value" "$tmpdir/clipboard"
printf '%0511d' 0 > "$tmpdir/value"
printf 'é\n' >> "$tmpdir/value"
"$cli" add SPLIT_UTF8 < "$tmpdir/value"
"$cli" copy SPLIT_UTF8
cmp -s "$tmpdir/value" "$tmpdir/clipboard"
env KCH_TEST_HEX=1001 "$cli" get SYNTHETIC > "$tmpdir/output"
printf '\020\001\n' | cmp -s - "$tmpdir/output"
if env KCH_TEST_HEX=610061 "$cli" get SYNTHETIC > "$tmpdir/output" 2>/dev/null; then exit 1; fi
[[ ! -s "$tmpdir/output" ]]
print 'Integration tests passed.'
