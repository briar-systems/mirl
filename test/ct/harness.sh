#!/usr/bin/env bash
# the timing-leak harness, dudect style. it runs locally on a linux x86-64 or
# aarch64 host, natively, and is never part of CI. risc-v runs only under
# qemu, where timing means nothing, so its code is judged by mirl's checks and
# masc's walk and never timed.
#
# usage: bash test/ct/harness.sh <run>
#
# <run> names a fresh directory out/ct/harness/<run>, which must not exist.
# mirl, masc and mink are taken from the path, as test/ct/tools.sh says.
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
# declines, with no verdict, rather than flake. a null is quiet whenever load
# swells the variance without moving the means, so it cannot see load that
# hides a leak: the planted control test/ct/leak/branch.mirl is timed before
# the cases and again after them, and a run that misses it either time measured
# nothing. that run declines, printing the control's |t|, its null's and each
# class's mean and spread, and withholds every case verdict timed between, a
# pass or a leak, since its controls do not vouch for them. the means tell a
# hidden leak (they differ) from a harness that cannot see one (they agree),
# and the harness never retries. a leak in every case is a broken harness, not
# a defect, since real leaks are selective.
#
# the exit status is 0 when the controls hold and no case leaks, 1 when a case
# leaks or a run is not whole or does not build, and 3 when the run declines:
# it measured nothing, so it is neither a pass nor a leak
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
[ -n "$lane" ] || { echo "harness.sh: test/lanes.sh names no linux $host_arch target" >&2; exit 2; }
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
            printf "%.3f %.1f %.1f %.1f %.1f\n", t, ma, mb, sqrt(va), sqrt(vb)
        }'
}

# the line of one run of the case built as `$1` with drawn inputs or not as
# `$2` says, into `$3`: |t|, each class's mean and each class's spread
timed() {
    local src=$1 drawn=$2 dir=$3 name
    name=$(basename "$src" .mirl)
    mkdir -p "$dir"
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
verdicts=()
fail() { verdicts+=("FAIL $1: $2"); fails=$((fails + 1)); }

# a run's measures as the report states them: its |t|, then each class's mean
# and spread in ticks
measured() {
    local t ma mb sa sb
    read -r t ma mb sa sb <<<"$1"
    echo "|t| = $t, fixed $ma (spread $sa), drawn $mb (spread $sb)"
}

# judge one case `$1` into `$out`, its verdict added to the report
judge() {
    local src=$1 name null test t
    name=$(basename "$src" .mirl)
    null=$(timed "$src" 0 "$out")
    case "$null" in
        unbuilt*|unrun*) fail "$name" "${null#* }"; return ;;
        malformed) fail "$name" "the null control's run is not whole"; return ;;
    esac
    t=${null%% *}
    if awk -v t="$t" -v n="$noise" 'BEGIN { exit !(t > n) }'; then
        verdicts+=("declined $name: the null control gives $(measured "$null"), the host is too noisy")
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
        fail "$name" "leaks, $(measured "$test") (null |t| = ${null%% *})"
        leaks=$((leaks + 1))
        return
    fi
    verdicts+=("ok   $name: |t| = $t (null ${null%% *})")
}

# time the planted control into `$1`, named `$2` in the report: return when it
# is flagged, and otherwise end the run, failing where a run is not whole or
# does not build and declining where the control's noise or a missed leak says
# the run measured nothing
control() {
    local dir=$1 when=$2 null test t withheld=""
    [ "${#verdicts[@]}" -gt 0 ] && withheld=", and the ${#verdicts[@]} case verdicts timed before it are withheld"
    null=$(timed "$here/leak/branch.mirl" 0 "$dir")
    case "$null" in
        unbuilt*|unrun*) echo "FAIL branch $when: ${null#* }"; exit 1 ;;
        malformed) echo "FAIL branch $when: the null control's run is not whole"; exit 1 ;;
    esac
    t=${null%% *}
    if awk -v t="$t" -v n="$noise" 'BEGIN { exit !(t > n) }'; then
        echo "declined: the planted control's null $when the cases gives $(measured "$null"), the host is too noisy$withheld"
        exit 3
    fi
    test=$(timed "$here/leak/branch.mirl" 1 "$dir")
    case "$test" in
        unbuilt*|unrun*) echo "FAIL branch $when: ${test#* }"; exit 1 ;;
        malformed) echo "FAIL branch $when: the run is not whole"; exit 1 ;;
    esac
    t=${test%% *}
    if awk -v t="$t" -v l="$leak" 'BEGIN { exit !(t > l) }'; then
        echo "ok   branch $when: the planted leak is flagged, |t| = $t"
        return
    fi
    echo "declined: the planted leak $when the cases is not flagged, $(measured "$test") (null |t| = ${null%% *}), so this run measured nothing$withheld"
    exit 3
}

control "$out/before" before
for src in "$here"/case/*.mirl; do
    cases=$((cases + 1))
    judge "$src"
done
control "$out/after" after
printf '%s\n' "${verdicts[@]}"
if [ "$declined" -gt 0 ]; then
    echo "declined: $declined runs found the host too noisy, so the harness gives no verdict"
    exit 3
fi
if [ "$cases" -gt 1 ] && [ "$leaks" -eq "$cases" ]; then
    echo "FAIL every case leaks: a uniform failure is a broken harness, not a defect"
fi
echo "$fails failed"
[ "$fails" -eq 0 ]
