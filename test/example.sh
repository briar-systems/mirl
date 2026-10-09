#!/usr/bin/env bash
# the lane of the example programs. it runs locally and is never part of CI.
#
# usage: bash test/example.sh <run>
#
# <run> names a fresh directory out/example/<run>, which must not exist. mirl
# must be built: mach build . -a cli. the qemu user emulator of every lane
# target and git must be on the path. the masc program and mink's exec driver
# are built from the pinned dep/masc and dep/mink, over the pinned dep/std and
# dep/mink, once per set of pins into out/example/tools/<pins>, with the
# compiler $MACH (mach by default). $MASC and $EXEC name built ones instead.
#
# the input set is every test/example/*.mirl, each a body for riscv64-linux
# whose line "; exits <n>: ..." states the status its program exits with, and
# test/example/exit.s, the __mirl_exit every start stub calls, which masc
# assembles for each lane target. the lane targets are the rows of LANES. an
# example is built for each by a copy whose target line names that target and
# is its only change, so an example states nothing a lane target lays out
# otherwise. for each example and each lane target the lane checks:
#   - mirl emit writes its object
#   - mirl emit writes its listing, which masc assembles again. a byte
#     difference from mirl's object shows masc disassemble of both, diffed
#   - once, the mach test unit roundtrip__every_example_listing_assembles_to_its_own_object
#     compares the reassembled objects of the examples as written as data,
#     which is the check that passes or fails
#   - mink's exec driver links the object and the exit object into a static
#     executable, which exits with the stated status under the lane's qemu
#
# the exit status is the number of checks that failed
set -u

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/.." && pwd)

[ $# -eq 1 ] || { sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)  host_dir=linux-x86_64 ;;
    Linux/aarch64) host_dir=linux-aarch64 ;;
    *) echo "example.sh: the lane runs on a linux host" >&2; exit 2 ;;
esac
mirl=$repo/out/$host_dir/debug/bin/mirl
[ -x "$mirl" ] || { echo "example.sh: $mirl is not built, run: mach build . -a cli" >&2; exit 2; }

out=$repo/out/example/$1
[ -e "$out" ] && { echo "example.sh: $out exists, name a fresh run" >&2; exit 2; }
mkdir -p "$out" || exit 2

# the target every example names
home=riscv64-linux

# each lane target: its mirl name, masc's reading of it, mink's architecture
# and the qemu that runs it
LANES=(
    "riscv64-linux|-t riscv64 --isa rv64gc --abi lp64d --format elf|riscv64|qemu-riscv64"
    "riscv32-linux|-t riscv32 --isa rv32gc --abi ilp32d --format elf|riscv32|qemu-riscv32"
)
for lane in "${LANES[@]}"; do
    IFS='|' read -r _ _ _ qemu <<<"$lane"
    command -v "$qemu" >/dev/null || { echo "example.sh: $qemu is not on the path" >&2; exit 2; }
done

# a shadow project of the pinned dependency `$1` in `$2`: its tracked files at
# the pin, with every dependency it declares taken from mirl's own dep/
shadow() {
    mkdir -p "$2" || return 1
    git -C "$repo/dep/$1" archive HEAD | tar -x -C "$2" || return 1
    awk -v dep="$repo/dep" '
        /^\[dep\./ { name = substr($0, 6, length($0) - 6); print; print "path = \"" dep "/" name "\""; skip = 1; next }
        /^\[/ { skip = 0 }
        skip && /^(git|ref|range) *=/ { next }
        { print }' "$repo/dep/$1/mach.toml" >"$2/mach.toml" || return 1
    "${MACH:-mach}" dep pull "$2" >/dev/null
}

# build the artifact `$2` of the pinned dependency `$1` into the tools of these
# pins, the program's path on stdout
tool() {
    local dir=$tools/$1
    if [ ! -x "$dir/out/$host_dir/debug/bin/$3" ]; then
        shadow "$1" "$dir" >&2 || { echo "example.sh: the shadow of dep/$1 was not made" >&2; return 1; }
        "${MACH:-mach}" build "$dir" -a "$2" >&2 || { echo "example.sh: dep/$1 -a $2 does not build" >&2; return 1; }
    fi
    echo "$dir/out/$host_dir/debug/bin/$3"
}

pins=$(git -C "$repo" submodule status dep | awk '{ sub(/^[-+ U]/, "", $1); printf "%s", substr($1, 1, 12) }')
tools=$repo/out/example/tools/$pins
masc=${MASC:-$(tool masc cli masc)} || exit 2
exec_bin=${EXEC:-$(tool mink exec exec)} || exit 2

fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# build and run the example `$1` at `$2` for the lane target `$3`, which masc
# reads as `$4`, mink links as `$5` and `$6` runs, into `$7`
example() {
    local name=$1 src=$2 target=$3 masc_as=$4 link=$5 qemu=$6 dir=$7
    local at="$dir/$name"
    local expect status
    expect=$(sed -n 's/^; exits \([0-9][0-9]*\):.*/\1/p' "$src")
    if [ -z "$expect" ]; then
        fail "$target $name" "states no exit status"
        return
    fi
    if [ "$target" != "$home" ]; then
        sed "s/^target \"$home\"\$/target \"$target\"/" "$src" >"$at.mirl"
        src=$at.mirl
    fi
    if ! "$mirl" emit "$src" --body --checked --kind object >"$at.o" 2>"$at.emit"; then
        fail "$target $name" "mirl emit refuses it: $(cat "$at.emit")"
        return
    fi
    if ! "$mirl" emit "$src" --body --checked --kind listing >"$at.s" 2>"$at.emit"; then
        fail "$target $name" "mirl emit refuses its listing: $(cat "$at.emit")"
        return
    fi
    if ! "$masc" assemble "$at.s" $masc_as -o "$at.rt.o" 2>"$at.as"; then
        fail "$target $name" "masc refuses the listing: $(cat "$at.as")"
        return
    fi
    if ! cmp -s "$at.o" "$at.rt.o"; then
        "$masc" disassemble "$at.o" $masc_as >"$at.dis" 2>&1
        "$masc" disassemble "$at.rt.o" $masc_as >"$at.rt.dis" 2>&1
        echo "note $target $name: the reassembled object differs in bytes, masc disassemble of mirl's and of the reassembled, diffed:"
        diff -u "$at.dis" "$at.rt.dis"
    fi
    if ! "$exec_bin" "$link" "$at" "$at.o" "$dir/exit.o" 2>"$at.link"; then
        fail "$target $name" "the link is refused: $(cat "$at.link")"
        return
    fi
    chmod +x "$at"
    "$qemu" "$at"
    status=$?
    if [ "$status" != "$expect" ]; then
        fail "$target $name" "exits $status, not $expect"
        return
    fi
    echo "ok   $target $name"
}

for lane in "${LANES[@]}"; do
    IFS='|' read -r target masc_as link qemu <<<"$lane"
    dir=$out/$target
    mkdir -p "$dir" || exit 2
    if ! "$masc" assemble "$here/example/exit.s" $masc_as -o "$dir/exit.o" 2>"$dir/exit.as"; then
        fail "$target exit" "masc refuses test/example/exit.s: $(cat "$dir/exit.as")"
        continue
    fi
    for src in "$here"/example/*.mirl; do
        name=$(basename "$src" .mirl)
        if ! grep -qx "target \"$home\"" "$src"; then
            fail "$target $name" "names no target $home"
            continue
        fi
        example "$name" "$src" "$target" "$masc_as" "$link" "$qemu" "$dir"
    done
done
# the exact comparison is the unit test, which reads both objects as data: every section's bytes, every relocation and
# every symbol by name, the one nameless symbol by its place. a byte difference above is shown for reading only
"${MACH:-mach}" test "$repo" -a '*' --filter roundtrip --timeout 5m >"$out/roundtrip.log" 2>&1 \
    || { fail "roundtrip" "the listing does not assemble to mirl's objects, see $out/roundtrip.log"; tail -n 20 "$out/roundtrip.log"; }
echo "$fails failed"
exit $fails
