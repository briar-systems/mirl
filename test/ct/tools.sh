# what the local constant-time suites share, sourced by test/ct/harness.sh and
# test/ct/oracle.sh: the host, the built mirl, the masc and mink programs of
# the pinned dep/masc and dep/mink, and a program built from one case.
#
# the masc and mink programs are built from the pinned dep/masc and dep/mink,
# over the pinned dep/std and dep/mink, once per set of pins into
# out/ct/tools/<pins>, with the compiler $MACH (mach by default), as
# test/example.sh builds them. $MASC and $MINK name built ones instead.

here=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(CDPATH= cd -- "$here/../.." && pwd)

case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)  host_dir=linux-x86_64; host_arch=x86_64 ;;
    Linux/aarch64) host_dir=linux-aarch64; host_arch=aarch64 ;;
    *) echo "the constant-time suites run on a linux x86-64 or aarch64 host" >&2; exit 2 ;;
esac
mirl=$repo/out/$host_dir/debug/bin/mirl
[ -x "$mirl" ] || { echo "$mirl is not built, run: mach build . -a cli" >&2; exit 2; }

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
        shadow "$1" "$dir" >&2 || { echo "the shadow of dep/$1 was not made" >&2; return 1; }
        "${MACH:-mach}" build "$dir" -a "$2" >&2 || { echo "dep/$1 -a $2 does not build" >&2; return 1; }
    fi
    echo "$dir/out/$host_dir/debug/bin/$3"
}

pins=$(git -C "$repo" submodule status dep | awk '{ sub(/^[-+ U]/, "", $1); printf "%s", substr($1, 1, 12) }')
tools=$repo/out/ct/tools/$pins
masc=${MASC:-$(tool masc cli masc)} || exit 2
mink=${MINK:-$(tool mink cli mink)} || exit 2

# the linux target of architecture `$1` the suites build for, in the columns
# `mirl lanes` writes: its name, architecture, system, environment, baseline,
# convention and format. x86-64's is its lane target, and aarch64, which no
# lane runs, takes its baseline armv8-a
lane_of() {
    case "$1" in
        aarch64) echo "aarch64-linux-gnu-aapcs64-armv8-a aarch64 linux gnu armv8-a aapcs64 elf" ;;
        *) "$mirl" lanes | awk -v arch="$1" '$2 == arch && $3 == "linux" { print; exit }' ;;
    esac
}

# the number a case states on its line `# <word> <n>`, `$2` when it states none
stated() {
    local n
    n=$(sed -n "s/^# $1 \\([0-9][0-9]*\\)\$/\\1/p" "$3" | head -n 1)
    echo "${n:-$2}"
}

# the word a case states on its line `# <word> <w>`
said() {
    sed -n "s/^# $1 \\([a-z][a-z]*\\)\$/\\1/p" "$2" | head -n 1
}

# build the program `$1`, a module text whose first line is its target statement,
# for the lane `$2` (`lane_of`'s line), linked with the host objects `$3...`.
# what mirl, masc and mink say lands beside it, and the reason a step refused
# is on stdout when it does
program() {
    local src=$1 lane=$2 at=${1%.mirl}
    shift 2
    local _ arch system env isa abi format
    read -r _ arch system env isa abi format <<<"$lane"
    if ! "$mirl" emit "$src" --body --checked --kind object >"$at.o" 2>"$at.emit"; then
        echo "mirl emit refuses it: $(cat "$at.emit")"
        return 1
    fi
    if ! "$mink" link "$at.o" "$@" -o "$at" --kind static --format "$format" --arch "$arch" --sys "$system" --env "$env" 2>"$at.link"; then
        echo "the link is refused: $(cat "$at.link")"
        return 1
    fi
    chmod +x "$at"
}

# assemble the host source `$1` for the lane `$2` into `$3`
assemble() {
    local _ arch system env isa abi format
    read -r _ arch system env isa abi format <<<"$2"
    "$masc" assemble "$1" --arch "$arch" --isa "$isa" --abi "$abi" --format "$format" -o "$3"
}

# the target statement of the lane `$1`
target_line() {
    local _ arch system env isa abi format
    read -r _ arch system env isa abi format <<<"$1"
    printf 'target { arch: "%s", sys: "%s", env: "%s", abi: "%s", isa: "%s" };\n' "$arch" "$system" "$env" "$abi" "$isa"
}
