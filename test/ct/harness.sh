#!/usr/bin/env bash
# the timing-leak harness, dudect style. it runs locally on a linux x86-64 or
# aarch64 host, natively, and is never part of CI. risc-v runs only under
# qemu, where timing means nothing, so its code is judged by mirl's checks and
# masc's walk and never timed.
#
# usage: bash test/ct/harness.sh <run>
#
# <run> names a fresh directory out/ct/harness/<run>, which must not exist.
# mirl must be built: mach build . -a cli. git must be on the path, and the
# masc and mink programs are built as test/ct/tools.sh says.
#
# each case is a test/ct/case/*.mirl body, a function probe(i64) i64
# that requires constant time and takes its input as a secret, and its line
# "# batch <n>" states how many calls one batch times, 1 for a case that probes
# addresses, since a larger batch averages one cache miss away. it is put
# after the host lane's target statement and before test/ct/driver.mirl, compiled
# by mirl, and linked by mink with test/ct/clock-<arch>.s, which masc
# assembles. the driver times $ROUNDS rounds (20000 by default), each one
# batch of the fixed input 0 and one of a drawn input, in alternating order.
# a run is whole when every round timed both classes and every statistic is a
# finite non-negative number, and a run that is not is a harness failure, not
# a verdict. Welch's |t| between the classes' batch times above $LEAK (10 by
# default) is a leak.
#
# the null control runs every case first with both classes the fixed input,
# sampled the same way, so it is cost-matched to the case. a null |t| above
# $NOISE (4.5 by default) says the host is too noisy to judge, and the harness
# declines, with no verdict, rather than flake. the planted control
# test/ct/leak/branch.mirl must be flagged, or the harness is blind and fails,
# and a leak in every case is a broken harness, not a defect, since real
# leaks are selective.
#
# the exit status is 0 when no case leaks, 3 when the harness declines and 1
# otherwise
set -u

[ $# -eq 1 ] || { sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tools.sh"

out=$repo/out/ct/harness/$1
[ -e "$out" ] && { echo "harness.sh: $out exists, name a fresh run" >&2; exit 2; }
mkdir -p "$out" || exit 2

rounds=${ROUNDS:-20000}
leak=${LEAK:-10}
noise=${NOISE:-4.5}

lane=$(lane_of "$host_arch")
[ -n "$lane" ] || { echo "harness.sh: mirl lanes names no linux $host_arch target" >&2; exit 2; }
line=$(target_line "$lane")
clock_s=$here/clock-$host_arch.s
if ! assemble "$clock_s" "$lane" "$out/clock.o" 2>"$out/clock.as"; then
    echo "harness.sh: masc refuses ${clock_s#$repo/}: $(cat "$out/clock.as")" >&2
    exit 2
fi

# Welch's |t| of the run's records on stdin, two i64 a round, the fixed
# class's first, or "malformed" when the run is not whole
welch() {
    od -An -v -t d8 -w16 | awk -v rounds="$rounds" '
        NF == 2 { n++; a = $1 + 0; b = $2 + 0
                  if (a < 0 || b < 0) bad = 1
                  da = a - ma; ma += da / n; sa += da * (a - ma)
                  db = b - mb; mb += db / n; sb += db * (b - mb) }
        NF != 2 && NF != 0 { bad = 1 }
        END {
            if (bad || n != rounds || n < 2) { print "malformed"; exit }
            va = sa / (n - 1); vb = sb / (n - 1); se = va / n + vb / n
            t = 0; if (se > 0) t = (ma - mb) / sqrt(se)
            if (t < 0) t = -t
            if (ma < 0 || mb < 0 || t != t) { print "malformed"; exit }
            printf "%.3f %.1f %.1f\n", t, ma, mb
        }'
}

# the |t| line of one run of the case built as `$1` with drawn inputs or not
# as `$2` says, into `$3`
timed() {
    local src=$1 drawn=$2 dir=$3 name
    name=$(basename "$src" .mirl)
    local at=$dir/$name.$drawn.mirl
    local batch
    batch=$(stated batch 8 "$src")
    {
        printf '%s\n' "$line"
        cat "$src"
        echo
        sed -e "s/\\\$SLOTS/$((2 * rounds))/g" -e "s/\\\$ROUNDS/$rounds/g" -e "s/\\\$INNER/$batch/g" \
            -e "s/\\\$FIXED/0/g" -e "s/\\\$DRAWN/$drawn/g" "$here/driver.mirl"
    } >"$at"
    local why
    if ! why=$(program "$at" "$lane" "$out/clock.o"); then
        echo "unbuilt $why"
        return
    fi
    if ! "${at%.mirl}" >"${at%.mirl}.records" 2>"${at%.mirl}.run"; then
        echo "unrun the program fails: $(cat "${at%.mirl}.run")"
        return
    fi
    welch <"${at%.mirl}.records"
}

fails=0
leaks=0
cases=0
declined=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# judge one case `$1`, a leak expected or not as `$2` says
judge() {
    local src=$1 planted=$2 name null test t
    name=$(basename "$src" .mirl)
    null=$(timed "$src" 0 "$out")
    case "$null" in
        unbuilt*|unrun*) fail "$name" "${null#* }"; return ;;
        malformed) fail "$name" "the null control's run is not whole"; return ;;
    esac
    t=${null%% *}
    if awk -v t="$t" -v n="$noise" 'BEGIN { exit !(t > n) }'; then
        echo "declined $name: the null control gives |t| = $t, the host is too noisy"
        declined=$((declined + 1))
        return
    fi
    test=$(timed "$src" 1 "$out")
    case "$test" in
        unbuilt*|unrun*) fail "$name" "${test#* }"; return ;;
        malformed) fail "$name" "the run is not whole"; return ;;
    esac
    t=${test%% *}
    if awk -v t="$t" -v l="$leak" 'BEGIN { exit !(t > l) }'; then
        if [ "$planted" = yes ]; then echo "ok   $name: the planted leak is flagged, |t| = $t"; return; fi
        fail "$name" "leaks, |t| = $t (null $null)"
        leaks=$((leaks + 1))
        return
    fi
    if [ "$planted" = yes ]; then
        fail "$name" "the planted leak is not flagged, |t| = $t, the harness is blind"
        return
    fi
    echo "ok   $name: |t| = $t (null ${null%% *})"
}

judge "$here/leak/branch.mirl" yes
for src in "$here"/case/*.mirl; do
    cases=$((cases + 1))
    judge "$src" no
done
if [ "$declined" -gt 0 ]; then
    echo "declined: $declined runs found the host too noisy, so the harness gives no verdict"
    exit 3
fi
if [ "$cases" -gt 1 ] && [ "$leaks" -eq "$cases" ]; then
    echo "FAIL every case leaks: a uniform failure is a broken harness, not a defect"
fi
echo "$fails failed"
[ "$fails" -eq 0 ]
