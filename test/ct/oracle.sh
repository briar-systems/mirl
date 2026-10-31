#!/usr/bin/env bash
# the independent constant-time oracle: established analyzers, written apart
# from mirl and masc, over the binaries mirl emits, so a shared assumption of
# the compiler and its checks does not hide a leak. it runs locally on a linux
# x86-64 or aarch64 host and is never part of CI.
#
# usage: bash test/ct/oracle.sh <run>
#
# <run> names a fresh directory out/ct/oracle/<run>, which must not exist.
# mirl must be built: mach build . -a cli. git, binsec and valgrind must be on
# the path, at the versions pinned below ($BINSEC and $VALGRIND name others).
# the masc and mink programs are built as test/ct/tools.sh says.
#
# the analyzers and the channels each covers:
#   - BINSEC's checkct: relational symbolic execution of the binary from
#     _start to __mirl_exit, the bytes at `secret` secret. it proves or finds
#     a counterexample for a branch and for a memory address a secret
#     decides: control and memory. it reads both architectures' binaries
#     without running them, so it runs over x86-64 and aarch64 alike.
#   - valgrind memcheck with the secret poisoned (ctgrind): the program marks
#     the bytes at `secret` undefined through a client request, and memcheck
#     reports a conditional jump or an address that depends on them: control
#     and memory. it runs the program, so it runs over the host's
#     architecture alone.
#   - neither covers the latency of an instruction whose timing depends on its
#     operands, which masc's rows state and mirl's checks and the harness
#     (test/ct/harness.sh) judge.
#
# the corpus is test/ct/case/*.mirl, the functions that require constant time,
# each a function probe(i64) i64 whose input is secret, which must run
# clean, and test/ct/leak/*.mirl, planted leaks that do not require constant
# time, so mirl compiles them, each stating its channel on its line
# "# channel <control|memory|latency>", which every analyzer that covers the
# channel must flag. a case is put after the lane's target statement, compiled by
# mirl and linked by mink with test/ct/oracle-<arch>.s, which masc assembles
# and which calls @probe once with the secret. a finding names the case, the
# analyzer and the analyzer's report, beside the program in the run's
# directory.
#
# the exit status is the number of checks that failed: a case mirl refuses or
# an analyzer flags, a planted leak an analyzer that covers its channel does
# not flag, and an analyzer that could not run
set -u

[ $# -eq 1 ] || { sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# the analyzers' versions the oracle is pinned to
binsec_pin=${BINSEC:-0.10.1}
valgrind_pin=${VALGRIND:-3.24.0}

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tools.sh"

command -v binsec >/dev/null || { echo "oracle.sh: binsec is not on the path" >&2; exit 2; }
command -v valgrind >/dev/null || { echo "oracle.sh: valgrind is not on the path" >&2; exit 2; }
binsec_at=$(binsec -version 2>&1 | head -n 1)
case "$binsec_at" in
    *"$binsec_pin"*) ;;
    *) echo "oracle.sh: binsec says '$binsec_at', the oracle is pinned to $binsec_pin" >&2; exit 2 ;;
esac
valgrind_at=$(valgrind --version 2>&1 | head -n 1)
[ "$valgrind_at" = "valgrind-$valgrind_pin" ] \
    || { echo "oracle.sh: valgrind says '$valgrind_at', the oracle is pinned to $valgrind_pin" >&2; exit 2; }

out=$repo/out/ct/oracle/$1
[ -e "$out" ] && { echo "oracle.sh: $out exists, name a fresh run" >&2; exit 2; }
mkdir -p "$out" || exit 2

fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# whether BINSEC's checkct finds the program `$1` insecure, its report in `$1.binsec`
binsec_flags() {
    cat >"$1.ini" <<EOF
starting from <_start>
secret global secret
halt at <__mirl_exit>
explore all
EOF
    binsec -checkct -checkct-script "$1.ini" "$1" >"$1.binsec" 2>&1 || return 2
    grep -q 'Program status is : insecure' "$1.binsec" && return 0
    grep -q 'Program status is : secure' "$1.binsec" && return 1
    return 2
}

# whether memcheck finds the program `$1` depending on the poisoned secret, its report in `$1.ctgrind`
ctgrind_flags() {
    valgrind --tool=memcheck --error-exitcode=99 --track-origins=yes "$1" >"$1.ctgrind" 2>&1
    case $? in
        0) return 1 ;;
        99) return 0 ;;
        *) return 2 ;;
    esac
}

# run the analyzer `$1` over the program `$2` of the case `$3`, which is clean
# or planted with the channel `$4` as it says
analyze() {
    local tool=$1 prog=$2 name=$3 channel=$4 got
    "${tool}_flags" "$prog"
    got=$?
    if [ "$got" -eq 2 ]; then fail "$name $tool" "the analyzer did not run, see $prog.$tool"; return; fi
    if [ -z "$channel" ]; then
        if [ "$got" -eq 0 ]; then fail "$name $tool" "flags constant-time code, see $prog.$tool"; return; fi
        echo "ok   $name $tool: clean"
        return
    fi
    case "$channel" in
        control|memory) ;;
        *) echo "skip $name $tool: it does not cover the $channel channel"; return ;;
    esac
    if [ "$got" -ne 0 ]; then fail "$name $tool" "misses the planted $channel leak, see $prog.$tool"; return; fi
    echo "ok   $name $tool: flags the planted $channel leak"
}

for arch in x86_64 aarch64; do
    lane=$(lane_of "$arch")
    [ -n "$lane" ] || { fail "$arch" "mirl lanes names no linux $arch target"; continue; }
    dir=$out/$arch
    mkdir -p "$dir" || exit 2
    start_s=$here/oracle-$arch.s
    if ! assemble "$start_s" "$lane" "$dir/start.o" 2>"$dir/start.as"; then
        fail "$arch start" "masc refuses ${start_s#$repo/}: $(cat "$dir/start.as")"
        continue
    fi
    for src in "$here"/case/*.mirl "$here"/leak/*.mirl; do
        name=$arch/$(basename "$(dirname "$src")")/$(basename "$src" .mirl)
        channel=
        case "$src" in "$here"/leak/*) channel=$(said channel "$src") ;; esac
        at=$dir/$(basename "$(dirname "$src")")-$(basename "$src")
        { target_line "$lane"; cat "$src"; } >"$at"
        if ! why=$(program "$at" "$lane" "$dir/start.o"); then
            fail "$name" "$why"
            continue
        fi
        analyze binsec "${at%.mirl}" "$name" "$channel"
        if [ "$arch" = "$host_arch" ]; then analyze ctgrind "${at%.mirl}" "$name" "$channel"; fi
    done
done
echo "$fails failed"
exit $fails
