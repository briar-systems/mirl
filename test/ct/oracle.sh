#!/usr/bin/env bash
# the independent constant-time oracle: established analyzers, written apart
# from mirl and masc, over the binaries mirl emits, so a shared assumption of
# the compiler and its checks does not hide a leak. it runs locally on a linux
# x86-64 or aarch64 host and is never part of CI.
#
# usage: bash test/ct/oracle.sh <run>
#
# <run> names a fresh directory out/ct/oracle/<run>, which must not exist.
# mirl, masc and mink are taken from the path, as test/ct/tools.sh says, and
# no build or git checkout is needed. readelf and od must be on the path.
#
# the analyzers, at the versions pinned below, and how to obtain each:
#   - BINSEC 0.10.0, as its published image binsec/binsec:0.10.0 builds it,
#     binsec commit c417273: tag 0.10.0 and one change to its documentation.
#     with docker, docker pull binsec/binsec:0.10.0 and set
#     BINSEC=test/ct/binsec.sh, which runs it in the image. opam's
#     binsec.0.10.0 is the same program.
#   - valgrind 3.25.1, the host's package or a build of the release.
# $BINSEC and $VALGRIND name the programs, binsec and valgrind on the path by
# default.
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
#     architecture alone, and aarch64 needs an aarch64 host.
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
# not flag, and an analyzer that could not run or could not decide
set -u

[ $# -eq 1 ] || { sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# the analyzers' versions the oracle is pinned to. a BINSEC built from the
# image says its commit, one built from the release says its version
binsec_version=0.10.0
binsec_commit=c417273
valgrind_version=3.25.1

# checkct's bound on the instructions of one path. BINSEC's default, 1000,
# cuts case/scan's walk of its 256-entry table, a path of about 3600
# instructions, and a cut path leaves the verdict unknown, so the bound sits
# far above the corpus's longest path
checkct_depth=100000

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tools.sh"

binsec=${BINSEC:-binsec}
valgrind=${VALGRIND:-valgrind}
for tool in "$binsec" "$valgrind" readelf od; do
    command -v "$tool" >/dev/null || { echo "oracle.sh: $tool is not on the path" >&2; exit 2; }
done
binsec_at=$("$binsec" -version 2>&1 | head -n 1)
case "$binsec_at" in
    *"$binsec_commit"*|*" $binsec_version") ;;
    *) echo "oracle.sh: binsec says '$binsec_at', the oracle is pinned to $binsec_version ($binsec_commit)" >&2; exit 2 ;;
esac
valgrind_at=$("$valgrind" --version 2>&1 | head -n 1)
[ "$valgrind_at" = "valgrind-$valgrind_version" ] \
    || { echo "oracle.sh: valgrind says '$valgrind_at', the oracle is pinned to $valgrind_version" >&2; exit 2; }

out=$repo/out/ct/oracle/$1
[ -e "$out" ] && { echo "oracle.sh: $out exists, name a fresh run" >&2; exit 2; }
mkdir -p "$out" || exit 2

fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# the checkct script's stubs for the DIT accesses of the aarch64 program `$1`.
# BINSEC's decoder interprets neither the read nor the write of PSTATE.DIT
# (mrs xt, DIT and msr DIT, xt or #imm), nor the barriers mirl puts after a
# write (dsb nsh, isb), and cuts every path through them. DIT changes how long
# data-processing instructions take, never what they compute, and a barrier
# orders memory and fetch, which changes no value in a program of one thread.
# so a read becomes a fresh public value in its register, which covers every
# value DIT can hold, and a write with its barriers becomes a jump past them.
# the instructions are found by their exact encodings at each address of the
# program's executable sections and nothing else is replaced, so any other
# instruction BINSEC cannot interpret still cuts the path and fails the check
dit_stubs() {
    local addr off size words i w at t
    while read -r addr off size; do
        mapfile -t words < <(od -An -v --endian=little -t x4 -w4 -j $((16#$off)) -N $((16#$size)) "$1" | tr -d ' ')
        for ((i = 0; i < ${#words[@]}; i++)); do
            w=$((16#${words[i]}))
            at=$((16#$addr + 4 * i))
            if (( (w & ~0x1f) == 0xd53b42a0 )); then
                t=$((w & 0x1f))
                printf 'replace 0x%x by\n' "$at"
                [ "$t" -ne 31 ] && printf '  x%d := nondet\n' "$t"
                printf '  jump at 0x%x\nend\n' $((at + 4))
            elif (( (w & ~0x1f) == 0xd51b42a0 || (w & ~0xf00) == 0xd503405f )); then
                printf 'replace 0x%x by\n' "$at"
                # dsb nsh, then isb
                [ "${words[i + 1]:-}" = d503379f ] && [ "${words[i + 2]:-}" = d5033fdf ] && i=$((i + 2))
                printf '  jump at 0x%x\nend\n' $((16#$addr + 4 * (i + 1)))
            fi
        done
    done < <(readelf -SW "$1" | awk '{ sub(/^ *\[ *[0-9]+\] */, ""); if ($2 == "PROGBITS" && $7 ~ /X/) print $3, $4, $5 }')
}

# whether BINSEC's checkct finds the program `$1` for the architecture `$2`
# insecure, its report in `$1.binsec`
binsec_flags() {
    {
        printf '%s\n' 'starting from <_start>' 'secret global secret' 'halt at <__mirl_exit>' 'explore all'
        if [ "$2" = aarch64 ]; then dit_stubs "$1"; fi
    } >"$1.ini"
    "$binsec" -sse -checkct -sse-depth "$checkct_depth" -sse-script "$1.ini" "$1" >"$1.binsec" 2>&1 || return 2
    grep -q 'Program status is : insecure' "$1.binsec" && return 0
    grep -q 'Program status is : secure' "$1.binsec" && return 1
    return 2
}

# whether memcheck finds the program `$1` depending on the poisoned secret, its report in `$1.ctgrind`
ctgrind_flags() {
    "$valgrind" --tool=memcheck --error-exitcode=99 --track-origins=yes "$1" >"$1.ctgrind" 2>&1
    case $? in
        0) return 1 ;;
        99) return 0 ;;
        *) return 2 ;;
    esac
}

# run the analyzer `$1` over the program `$2` for the architecture `$5` of the
# case `$3`, which is clean or planted with the channel `$4` as it says
analyze() {
    local tool=$1 prog=$2 name=$3 channel=$4 arch=$5 got
    "${tool}_flags" "$prog" "$arch"
    got=$?
    if [ "$got" -eq 2 ]; then fail "$name $tool" "the analyzer did not run or did not decide, see $prog.$tool"; return; fi
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
    [ -n "$lane" ] || { fail "$arch" "test/lanes.sh names no linux $arch target"; continue; }
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
        analyze binsec "${at%.mirl}" "$name" "$channel" "$arch"
        if [ "$arch" = "$host_arch" ]; then analyze ctgrind "${at%.mirl}" "$name" "$channel" "$arch"; fi
    done
done
echo "$fails failed"
exit $fails
