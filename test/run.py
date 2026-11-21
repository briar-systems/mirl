#!/usr/bin/env python3
# mirl's ir corpus: every file under test/ir compiles, unoptimised and optimised, with
# every verifier and the allocation proof on, for the target its own statement names or
# for each target its header names. a file is a body that starts with its target
# statement and has no version statement, so the run puts the library's own,
# `mirl "<mirl --version>";`, before a copy of it.
#
#   test/run.py [--mirl <path>] [--jobs <n>] [filter...]
#
# a filter is a substring of a file's path. output goes to test/out, which must not be
# shared with another run at once.
# a `# targets:` line in a file's header names the targets it compiles for instead of its
# own, as `-t` spells them, as a case the walk of constant-time code must accept on each
# architecture that runs it at emission.
# a `# flags:` line adds its words to every compile of the file.
# a `# refuse:` line states that every compile of the file is refused, its report, its lines
# joined by spaces, holding the line's text, as a case the walk of constant-time code must
# refuse on each target it names.
# exit 0: nothing failed.
import argparse, concurrent.futures, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# the two states of a build, as `mirl compile` spells them
STATES = (('off', ['--no-optimize']), ('on', ['--optimize']))


def header(path):
    # the leading `# key: value` comment lines after a file's target statement
    out = {}
    lines = open(path, encoding='utf-8').read().splitlines()
    for line in lines[1:]:
        m = re.match(r'#\s*([a-z]+):\s*(.*\S)\s*$', line)
        if not m:
            break
        out[m.group(1)] = m.group(2)
    return out


def corpus():
    found = []
    for d, _, fs in os.walk(os.path.join(HERE, 'ir')):
        found += [os.path.join(d, f) for f in fs if f.endswith('.mirl')]
    return sorted(found)


def one(cfg, version, path):
    # every compile of one file, a line per failure
    rel = os.path.relpath(path, HERE)
    name = rel[:-len('.mirl')].replace(os.sep, '-')
    out = os.path.join(HERE, 'out', 'ir')
    text = os.path.join(out, name + '.mirl')
    with open(text, 'w', encoding='utf-8') as f:
        f.write(f'mirl "{version}";\n' + open(path, encoding='utf-8').read())
    h = header(path)
    targets = h.get('targets', '').replace(',', ' ').split() or [None]
    fails, done = [], 0
    for t in targets:
        for state, words in STATES:
            where = t or 'own'
            cmd = [cfg.mirl, 'compile', text, *words, '--verify', *h.get('flags', '').split(),
                   '-o', os.path.join(out, f'{name}.{where}.{state}.o')]
            if t:
                cmd += ['-t', t]
            p = subprocess.run(cmd, capture_output=True, text=True)
            done += 1
            said = [l.strip() for l in (p.stderr + p.stdout).splitlines() if l.strip() and not l.startswith('warning')]
            refuse = h.get('refuse')
            if refuse is not None:
                if p.returncode == 0:
                    fails.append(f'{rel} [{where}, {state}] compiled, where it must be refused: {refuse}')
                elif refuse not in ' '.join(said):
                    fails.append(f'{rel} [{where}, {state}] refused without `{refuse}`: ' + ' '.join(said[:3]))
            elif p.returncode != 0:
                fails.append(f'{rel} [{where}, {state}] exit {p.returncode}: ' + ' '.join(said[:3]))
    return done, fails


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mirl', default=os.path.join(ROOT, 'out', 'linux-x86_64', 'debug', 'bin', 'mirl'))
    ap.add_argument('--jobs', type=int, default=os.cpu_count() or 1)
    ap.add_argument('filter', nargs='*')
    cfg = ap.parse_args()
    if not os.path.isfile(cfg.mirl):
        sys.exit(f'{cfg.mirl} is not built: mach build . -a cli')
    version = subprocess.run([cfg.mirl, '--version'], capture_output=True, text=True).stdout.strip()
    os.makedirs(os.path.join(HERE, 'out', 'ir'), exist_ok=True)
    files = [p for p in corpus() if not cfg.filter or any(f in p for f in cfg.filter)]
    fails, done = [], 0
    with concurrent.futures.ThreadPoolExecutor(cfg.jobs) as pool:
        for n, f in pool.map(lambda p: one(cfg, version, p), files):
            done += n
            fails += f
    print(f'ir: {len(files)} files, {done} compiles, {len(fails)} failed')
    for f in fails:
        print('FAIL ' + f)
    print(f'{len(fails)} failed' if fails else 'ok')
    sys.exit(1 if fails else 0)


main()
