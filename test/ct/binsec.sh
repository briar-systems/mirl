#!/usr/bin/env bash
# binsec at the oracle's pin, run from its published container image, for a
# host with docker and no binsec of its own: BINSEC=test/ct/binsec.sh. the
# image's tag 0.10.0 is binsec commit c417273 (tag 0.10.0 and one change to its
# documentation), held here by digest. the directory of every absolute path
# among the arguments is mounted read-only at that same path, so binsec reads
# the oracle's programs and scripts where the oracle names them, and its report
# is its output
set -u

image=binsec/binsec:0.10.0@sha256:37ba084e50afa99d5aa5007260ef263997303752dfdbfe3977782c661f8d85d5

declare -A seen=()
mounts=()
for arg in "$@"; do
    case "$arg" in /*) ;; *) continue ;; esac
    [ -e "$arg" ] || continue
    dir=$(dirname -- "$arg")
    [ -n "${seen[$dir]:-}" ] && continue
    seen[$dir]=1
    mounts+=(-v "$dir:$dir:ro")
done
exec docker run --rm -i --network none "${mounts[@]}" -w /tmp "$image" binsec "$@"
