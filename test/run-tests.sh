#!/usr/bin/env bash
#
# Test suite for ttp.  Run it with the bash you want to test, e.g.
#
#   bash test/run-tests.sh
#   /bin/bash test/run-tests.sh     # bash 3.2 on macOS
#
# ttp itself is run with the same bash.  Requires gpg.  Nothing outside
# a temporary directory is touched; gpg runs with its own GNUPGHOME and a
# fixed passphrase.

export LC_ALL=C
cd "$(dirname "$0")/.." || exit 1
ttp=$PWD/ttp
tests=0
failures=0

fail() {
    failures=$((failures + 1))
    echo "FAIL: $1"
    shift
    for line in "$@"; do
        echo "      $line"
    done
}

# check NAME EXPECTED ACTUAL
check() {
    tests=$((tests + 1))
    if test "$2" != "$3"; then
        fail "$1" "expected: $2" "actual:   $3"
    fi
}

# check_contains NAME NEEDLE HAYSTACK
check_contains() {
    tests=$((tests + 1))
    case "$3" in
        *"$2"*) ;;
        *) fail "$1" "expected to contain: $2" "actual: $3" ;;
    esac
}

# Set the global array "bytes" to the bytes of string $1.
to_bytes() {
    local i c
    bytes=()
    for ((i = 0; i < ${#1}; i++)); do
        printf -v c '%d' "'${1:i:1}"
        bytes+=("$c")
    done
}

# Set "bytes" to $2 copies of byte $1.
repeat_byte() {
    local i
    bytes=()
    for ((i = 0; i < $2; i++)); do
        bytes+=("$1")
    done
}

hex() {
    printf '%02x' "$@"
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/ttp-test.XXXXXX") || exit 1
cleanup() {
    GNUPGHOME=$tmp/gnupg gpgconf --kill gpg-agent > /dev/null 2>&1
    rm -rf "$tmp"
}
trap cleanup EXIT

########################################################################
# Unit tests: source ttp and call its functions directly.

source "$ttp"

echo "Testing sha1"
sha1_in=()
sha1
check "sha1 of empty string" da39a3ee5e6b4b0d3255bfef95601890afd80709 "$(hex "${sha1_out[@]}")"
to_bytes abc
sha1_in=("${bytes[@]}")
sha1
check "sha1 of abc" a9993e364706816aba3e25717850c26c9cd0d89d "$(hex "${sha1_out[@]}")"
to_bytes abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq
sha1_in=("${bytes[@]}")
sha1
check "sha1 of 56-byte string" 84983e441c3bd26ebaae4aa1f95129e5e54670f1 "$(hex "${sha1_out[@]}")"

# Compare against the system's sha1 tool across the padding boundaries.
if command -v sha1sum > /dev/null; then
    sha1tool=sha1sum
elif command -v shasum > /dev/null; then
    sha1tool=shasum
else
    sha1tool=
fi
if test -n "$sha1tool"; then
    for len in 1 54 55 56 57 63 64 65 119 120 128 200; do
        sha1_in=()
        escapes=
        for ((i = 0; i < len; i++)); do
            sha1_in+=($(( (i * 37 + len) & 255 )))
            escapes+=$(printf '\\%03o' $(( (i * 37 + len) & 255 )))
        done
        printf "$escapes" > "$tmp/blob"
        sha1
        want=$($sha1tool < "$tmp/blob")
        check "sha1 of $len bytes matches $sha1tool" "${want%% *}" "$(hex "${sha1_out[@]}")"
    done
else
    echo "  (no sha1sum or shasum found; skipping comparison)"
fi

echo "Testing hmac_sha1 (RFC 2202 test cases)"
repeat_byte 11 20
hmac_key=("${bytes[@]}")
to_bytes "Hi There"
hmac_msg=("${bytes[@]}")
hmac_sha1
check "RFC 2202 case 1" b617318655057264e28bc0b6fb378c8ef146be00 "$(hex "${sha1_out[@]}")"

to_bytes Jefe
hmac_key=("${bytes[@]}")
to_bytes "what do ya want for nothing?"
hmac_msg=("${bytes[@]}")
hmac_sha1
check "RFC 2202 case 2" effcdf6ae5eb2fa2d27416d5f184df9c259a7c79 "$(hex "${sha1_out[@]}")"

repeat_byte 170 20
hmac_key=("${bytes[@]}")
repeat_byte 221 50
hmac_msg=("${bytes[@]}")
hmac_sha1
check "RFC 2202 case 3" 125d7342b9ac11cd91a39af48aa17b4f63f175d3 "$(hex "${sha1_out[@]}")"

repeat_byte 170 80
hmac_key=("${bytes[@]}")
to_bytes "Test Using Larger Than Block-Size Key - Hash Key First"
hmac_msg=("${bytes[@]}")
hmac_sha1
check "RFC 2202 case 6 (key longer than a block)" aa4ae5e15272d00e95705637ce8a3b55ed402112 "$(hex "${sha1_out[@]}")"

echo "Testing totp"
# The RFC 4226 and RFC 6238 test key, "12345678901234567890", in base32.
key=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ

# RFC 6238 appendix B (SHA1, 8 digits).
for vector in 59:94287082 1111111109:07081804 1111111111:14050471 \
              1234567890:89005924 2000000000:69279037 20000000000:65353130; do
    time=${vector%%:*}
    check "RFC 6238 at time $time" "${vector#*:}" \
        "$(echo "otpauth://totp/test?secret=$key&digits=8" | totp "$time")"
done

# RFC 4226 appendix D (6 digits); counter c is time c * 30.
counter=0
for want in 755224 287082 359152 969429 338314 254676 287922 162583 399871 520489; do
    check "RFC 4226 counter $counter" "$want" "$(echo "$key" | totp $((counter * 30)))"
    counter=$((counter + 1))
done

check "lowercase key" 287082 "$(echo "$key" | tr A-Z a-z | totp 30)"
check "key with spaces and tabs" 287082 "$(printf 'GEZD GNBV\tGY3T QOJQ GEZDGNBVGY3TQOJQ\n' | totp 30)"
check "padded key" "$(echo MZXW6 | totp 30)" "$(echo 'MZXW6===' | totp 30)"
check "URI with secret first" 287082 "$(echo "otpauth://totp/a:b?secret=$key&issuer=a" | totp 30)"
check "URI with secret last" 287082 "$(echo "otpauth://totp/a:b?issuer=a&secret=$key" | totp 30)"
check "URI with SHA1 algorithm" 287082 "$(echo "otpauth://totp/a?secret=$key&algorithm=SHA1" | totp 30)"
check "URI with 60 second period" 359152 "$(echo "otpauth://totp/a?secret=$key&period=60" | totp 120)"
check "URI with a key line and no newline" 287082 "$(printf '%s' "$key" | totp 30)"

# expect_error NAME MESSAGE INPUT
expect_error() {
    local out rc
    out=$(printf '%s' "$3" | totp 30 2>&1)
    rc=$?
    check "$1: exit status" 1 "$rc"
    check_contains "$1: message" "$2" "$out"
}
expect_error "empty input" "aborted" ""
expect_error "invalid character" "bad key" $'ABC!EFGH\n'
expect_error "invalid length" "bad key" $'A\n'
expect_error "URI without secret" "bad key" $'otpauth://totp/a?issuer=a\n'
expect_error "URI without query" "bad key" $'otpauth://totp/a\n'
expect_error "HOTP URI" "bad key" "otpauth://hotp/a?secret=$key&counter=1"$'\n'
expect_error "SHA256 URI" "unsupported algorithm" "otpauth://totp/a?secret=$key&algorithm=SHA256"$'\n'
expect_error "zero digits" "unsupported number of digits" "otpauth://totp/a?secret=$key&digits=0"$'\n'
expect_error "11 digits" "unsupported number of digits" "otpauth://totp/a?secret=$key&digits=11"$'\n'
expect_error "zero period" "unsupported period" "otpauth://totp/a?secret=$key&period=0"$'\n'
expect_error "non-numeric period" "unsupported period" "otpauth://totp/a?secret=$key&period=x"$'\n'

# Bash arithmetic evaluates command substitutions in array subscripts,
# so make sure URI parameters never reach it unchecked.
for param in digits period; do
    rm -f "$tmp/pwned"
    expect_error "code in $param" "unsupported" \
        "otpauth://totp/a?secret=$key&$param=a[\$(touch $tmp/pwned)]"$'\n'
    check "code in $param is not run" no "$(test -e "$tmp/pwned" && echo yes || echo no)"
done

########################################################################
# Command-line tests: run ttp as a program, with gpg wrapped to use a
# fixed passphrase and no prompts.

echo "Testing the ttp command"
real_gpg=$(command -v gpg) || { echo "gpg is required"; exit 1; }
mkdir -p "$tmp/bin" "$tmp/failbin" "$tmp/gnupg" "$tmp/config"
chmod 700 "$tmp/gnupg"
cat > "$tmp/bin/gpg" <<EOF
#!/bin/sh
exec "$real_gpg" --batch --passphrase test-passphrase "\$@"
EOF
# qrencode stand-in that prints what it would encode.
cat > "$tmp/bin/qrencode" <<'EOF'
#!/bin/sh
cat
echo
EOF
# gpg stand-in that always fails.
printf '#!/bin/sh\nexit 2\n' > "$tmp/failbin/gpg"
chmod +x "$tmp/bin/gpg" "$tmp/bin/qrencode" "$tmp/failbin/gpg"

export PATH="$tmp/bin:$PATH" GNUPGHOME="$tmp/gnupg" XDG_CONFIG_HOME="$tmp/config"
unset DISPLAY WAYLAND_DISPLAY

# run ARGS...: run ttp, setting $out and $rc.
run() {
    out=$("$BASH" "$ttp" "$@" 2>&1)
    rc=$?
}

run -xc demo <<< "$key"
check "-xc: exit status" 0 "$rc"
check "-xc: key file created" yes "$(test -f "$tmp/config/ttp/demo.gpg" && echo yes)"
check "-xc: key file is private" "-rw-------" "$(ls -l "$tmp/config/ttp/demo.gpg" | cut -c1-10)"

run -l
check "-l: lists keys" demo "$out"

# The code depends on the current time, so accept the code from just
# before or just after running ttp.
before=$(echo "$key" | totp)
run -x demo
after=$(echo "$key" | totp)
check "-x: exit status" 0 "$rc"
check "-x: prints current code" yes \
    "$(test "$out" = "$before" -o "$out" = "$after" && echo yes || echo "no ($out)")"

run -xc demo <<< "$key"
check "-xc existing key: exit status" 1 "$rc"
check_contains "-xc existing key: message" "exists already" "$out"

run -x nosuch
check "-x unknown service: exit status" 1 "$rc"
check_contains "-x unknown service: message" "no key for nosuch" "$out"

run -xv nosuch
check "-xv unknown service: exit status" 1 "$rc"

for args in "" "-c" "-x" "a b c"; do
    run $args
    check "usage for '$args': exit status" 1 "$rc"
    check_contains "usage for '$args': message" "usage:" "$out"
done

run -xc empty <<< ""
check "-xc with no key: exit status" 0 "$rc"
check_contains "-xc with no key: message" "Aborted." "$out"
check "-xc with no key: no file" no "$(test -e "$tmp/config/ttp/empty.gpg" && echo yes || echo no)"

run -xc bad <<< "NOT!VALID"
check "-xc with bad key: exit status" 1 "$rc"
check "-xc with bad key: no file" no "$(test -e "$tmp/config/ttp/bad.gpg" && echo yes || echo no)"

out=$(PATH="$tmp/failbin:$PATH" "$BASH" "$ttp" -xc broken <<< "$key" 2>&1)
check "-xc when gpg fails: exit status" 1 "$?"

for name in ../escape a/b .hidden -dash; do
    for mode in -xc -x -xv; do
        run $mode "$name" <<< "$key"
        check "$mode '$name': exit status" 1 "$rc"
        # With -x, a lone "-dash" argument is rejected as an unknown option.
        case "$mode $name" in
            "-x -dash") want="usage:" ;;
            *) want="invalid service name" ;;
        esac
        check_contains "$mode '$name': message" "$want" "$out"
    done
done
check "invalid names: no files written" "demo.gpg" "$(cd "$tmp/config/ttp" && echo *)"
check "invalid names: nothing outside the key directory" no \
    "$(test -e "$tmp/config/escape.gpg" && echo yes || echo no)"

run -xc "my bank" <<< "$key"
check "-xc name with a space: exit status" 0 "$rc"
run -x "my bank"
check "-x name with a space: exit status" 0 "$rc"
rm -f "$tmp/config/ttp/my bank.gpg"

# Clipboard tools.  Each stand-in records its arguments and input.
mkdir -p "$tmp/clipbin"
for tool in wl-copy xclip xsel; do
    cat > "$tmp/clipbin/$tool" <<EOF
#!/bin/sh
echo "$tool \$*" > "$tmp/clip"
cat >> "$tmp/clip"
EOF
    chmod +x "$tmp/clipbin/$tool"
done

# clip ENV...: get a code without -x, with the given environment and the
# stand-in clipboard tools first on PATH, setting $out, $rc and $clip.
clip() {
    rm -f "$tmp/clip"
    out=$(env PATH="$tmp/clipbin:$PATH" "$@" "$BASH" "$ttp" demo 2>&1)
    rc=$?
    clip=$(cat "$tmp/clip" 2>/dev/null)
}
before=$(echo "$key" | totp)
clip WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
after=$(echo "$key" | totp)
copied=${clip#*$'\n'}
check "Wayland: exit status" 0 "$rc"
check "Wayland: message" "Sending code to Wayland clipboard" "$out"
check "Wayland: uses wl-copy" "wl-copy " "${clip%%$'\n'*}"
check "Wayland: copies the code" yes \
    "$(test "$copied" = "$before" -o "$copied" = "$after" && echo yes || echo "no ($copied)")"

clip DISPLAY=:0
check "X11: message" "Sending code to X clipboard" "$out"
check "X11: xclip uses the Ctrl-V clipboard" "xclip -selection clipboard -i" "${clip%%$'\n'*}"

rm "$tmp/clipbin/xclip"
clip DISPLAY=:0
check "X11 without xclip: xsel uses the Ctrl-V clipboard" "xsel --clipboard --input" "${clip%%$'\n'*}"

rm -f "$tmp/clip"
out=$(env PATH="$tmp/clipbin:$PATH" WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 "$BASH" "$ttp" -x demo 2>&1)
check "-x with Wayland and X11: prints the code" 6 "${#out}"
check "-x with Wayland and X11: no clipboard" no "$(test -e "$tmp/clip" && echo yes || echo no)"

uri="otpauth://totp/Example%3Aalice%40example.com?secret=$key&issuer=Example&digits=8"
run -xc eight <<< "$uri"
check "-xc with URI: exit status" 0 "$rc"
run -x eight
check "-x with 8-digit URI: length" 8 "${#out}"

run -xv eight
check "-xv with URI: prints URI unchanged" "$uri" "$out"
run -xv demo
check "-xv with plain key: builds URI" "otpauth://totp/demo?secret=$key&issuer=demo" "$out"

# Keys left in ~/.config/ga by older versions are still found.
mkdir -p "$tmp/legacy/ga"
cp "$tmp/config/ttp/demo.gpg" "$tmp/legacy/ga/old.gpg"
out=$(XDG_CONFIG_HOME=$tmp/legacy "$BASH" "$ttp" -l 2>&1)
check "legacy ~/.config/ga: -l" old "$out"
before=$(echo "$key" | totp)
out=$(XDG_CONFIG_HOME=$tmp/legacy "$BASH" "$ttp" -x old 2>&1)
after=$(echo "$key" | totp)
check "legacy ~/.config/ga: -x" yes \
    "$(test "$out" = "$before" -o "$out" = "$after" && echo yes || echo "no ($out)")"

########################################################################

echo
echo "bash $BASH_VERSION: $((tests - failures)) of $tests checks passed"
test "$failures" -eq 0
