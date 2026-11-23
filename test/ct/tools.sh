# what the local constant-time suites share, sourced by test/ct/harness.sh and
# test/ct/oracle.sh: the host, the mirl, masc and mink programs, the lane
# target and a program built from one case.
#
# mirl, masc and mink are taken from the path, the toolchain under test, so no
# build or git checkout is needed. $MIRL, $MASC and $MINK name other programs.
#
# $OPTIMIZE set to 1 compiles every case with mirl's optimisation passes (-O),
# off by default, so each suite runs over the optimiser too:
# OPTIMIZE=1 bash test/ct/oracle.sh <run>.

here=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(CDPATH= cd -- "$here/../.." && pwd)

case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)  host_arch=x86_64 ;;
    Linux/aarch64) host_arch=aarch64 ;;
    *) echo "the constant-time suites run on a linux x86-64 or aarch64 host" >&2; exit 2 ;;
esac
mirl=${MIRL:-mirl}
masc=${MASC:-masc}
mink=${MINK:-mink}
for tool in "$mirl" "$masc" "$mink"; do
    command -v "$tool" >/dev/null || { echo "$tool is not on the path" >&2; exit 2; }
done

# the linux target of architecture `$1` the suites build for, its line of
# test/lanes.sh: its target, architecture, system, environment, baseline and
# convention
. "$repo/test/lanes.sh"
lane_of() {
    awk -v arch="$1" '$2 == arch && $3 == "linux" { print; exit }' <<<"$lanes"
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
    local target arch system env isa abi
    read -r target arch system env isa abi <<<"$lane"
    # the case is a body, so it is read under the library's own version statement
    { printf 'mirl "%s";\n' "$("$mirl" --version)"; cat "$src"; } >"$at.text.mirl"
    if ! "$mirl" compile "$at.text.mirl" $([ "${OPTIMIZE:-0}" = 1 ] && echo -O) --verify --emit obj -o "$at.o" 2>"$at.emit"; then
        echo "mirl compile refuses it: $(cat "$at.emit")"
        return 1
    fi
    if ! "$mink" link "$at.o" "$@" -o "$at" --kind bin --linkage static -t "$target" --env "$env" --abi "$abi" 2>"$at.link"; then
        echo "the link is refused: $(cat "$at.link")"
        return 1
    fi
    chmod +x "$at"
}

# assemble the host source `$1` for the lane `$2` into `$3`
assemble() {
    local target arch system env isa abi
    read -r target arch system env isa abi <<<"$2"
    "$masc" assemble "$1" -t "$target" --env "$env" --isa "$isa" --abi "$abi" -o "$3"
}

# the target statement of the lane `$1`
target_line() {
    local _ arch system env isa abi
    read -r _ arch system env isa abi <<<"$1"
    printf 'target { arch: "%s", sys: "%s", env: "%s", abi: "%s", isa: "%s" };\n' "$arch" "$system" "$env" "$abi" "$isa"
}
