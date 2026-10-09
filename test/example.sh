#!/usr/bin/env bash
# the lane of the example programs. it runs locally and is never part of CI.
#
# usage: bash test/example.sh <run>
#
# <run> names a fresh directory out/example/<run>, which must not exist. mirl
# must be built: mach build . -a cli. qemu-riscv64 and git must be on the
# path. the masc program and mink's exec driver are built from the pinned
# dep/masc and dep/mink, over the pinned dep/std and dep/mink, once per set of
# pins into out/example/tools/<pins>, with the compiler $MACH (mach by
# default). $MASC and $EXEC name built ones instead.
#
# the input set is every test/example/*.mirl, each a body for riscv64-linux
# whose line "; exits <n>: ..." states the status its program exits with, and
# test/example/exit.s, the __mirl_exit every start stub calls, which masc
# assembles. for each example the lane checks:
#   - mirl emit writes its object
#   - mirl emit writes its listing, which masc assembles to the same bytes as
#     mirl's own object, compared in the one name an object keeps nameless by
#     where it is placed. a mismatch shows masc disassemble of both, diffed
#   - mink's exec driver links the object and the exit object into a static
#     executable, which exits with the stated status under qemu-riscv64
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
command -v qemu-riscv64 >/dev/null || { echo "example.sh: qemu-riscv64 is not on the path" >&2; exit 2; }

out=$repo/out/example/$1
[ -e "$out" ] && { echo "example.sh: $out exists, name a fresh run" >&2; exit 2; }
mkdir -p "$out" || exit 2

# the target every example names, and masc's reading of it
target=riscv64-linux
masc_as="-t riscv64 --isa rv64gc --abi lp64d --format elf"

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

"$masc" assemble "$here/example/exit.s" $masc_as -o "$out/exit.o" 2>"$out/exit.as" \
    || { echo "example.sh: masc refuses test/example/exit.s: $(cat "$out/exit.as")" >&2; exit 2; }

fails=0
fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

for src in "$here"/example/*.mirl; do
    name=$(basename "$src" .mirl)
    if ! grep -qx "target \"$target\"" "$src"; then
        fail "$name" "names no target $target"
        continue
    fi
    expect=$(sed -n 's/^; exits \([0-9][0-9]*\):.*/\1/p' "$src")
    if [ -z "$expect" ]; then
        fail "$name" "states no exit status"
        continue
    fi
    if ! "$mirl" emit "$src" --body --checked --kind object >"$out/$name.o" 2>"$out/$name.emit"; then
        fail "$name" "mirl emit refuses it: $(cat "$out/$name.emit")"
        continue
    fi
    if ! "$mirl" emit "$src" --body --checked --kind listing >"$out/$name.s" 2>"$out/$name.emit"; then
        fail "$name" "mirl emit refuses its listing: $(cat "$out/$name.emit")"
        continue
    fi
    if ! "$masc" assemble "$out/$name.s" $masc_as -o "$out/$name.rt.o" 2>"$out/$name.as"; then
        fail "$name" "masc refuses the listing: $(cat "$out/$name.as")"
        continue
    fi
    if ! cmp -s "$out/$name.o" "$out/$name.rt.o"; then
        "$masc" disassemble "$out/$name.o" $masc_as >"$out/$name.dis" 2>&1
        "$masc" disassemble "$out/$name.rt.o" $masc_as >"$out/$name.rt.dis" 2>&1
        if ! diff -q "$out/$name.dis" "$out/$name.rt.dis" >/dev/null; then
            fail "$name" "the listing assembles to other bytes: diff of masc disassemble of mirl's object and of the reassembled one"
            diff -u "$out/$name.dis" "$out/$name.rt.dis"
            continue
        fi
    fi
    if ! "$exec_bin" riscv64 "$out/$name" "$out/$name.o" "$out/exit.o" 2>"$out/$name.link"; then
        fail "$name" "the link is refused: $(cat "$out/$name.link")"
        continue
    fi
    chmod +x "$out/$name"
    qemu-riscv64 "$out/$name"
    status=$?
    if [ "$status" != "$expect" ]; then
        fail "$name" "exits $status, not $expect"
        continue
    fi
    echo "ok   $name"
done
echo "$fails failed"
exit $fails
