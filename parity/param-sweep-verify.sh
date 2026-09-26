#!/usr/bin/env bash
# param-sweep-verify.sh — graph-level per-effect parameter sweep gate (GAP-001).
#
# Regenerates the parameter-variant corpus from the pinned reference authority
# (parity/programs/param-sweep/ must regenerate byte-identically), compiles the
# golden graph with the reference oracle (tools/export-graph.mjs) and the C# live
# DSL compiler (tools/graphdump, .NET 8 — no Unity editor needed), and diffs every
# variant with parity/graph-diff.py. Fail-closed: any FAIL, missing graph, oracle
# error, or corpus drift is nonzero.
#
# Env:
#   NM_REFERENCE_ROOT  pinned reference repo (default ../../noisemaker)
#   DOTNET             dotnet executable (default: dotnet on PATH)
#
# Usage: bash parity/param-sweep-verify.sh [workDir]   (default: /tmp/param-sweep)
set -eu
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/param-sweep}"
DOTNET="${DOTNET:-dotnet}"
CORPUS="$ROOT/parity/programs/param-sweep"

echo "=== [1/4] regenerate corpus ==="
rm -rf "$OUT"
mkdir -p "$OUT/ref" "$OUT/cs"
node "$ROOT/parity/param-sweep.mjs" "$OUT" > "$OUT/generate.log"
cat "$OUT/generate.log"

# The committed corpus is the fixed input; regeneration must reproduce it.
if ! diff -r --exclude=ref --exclude=cs --exclude='*.log' --exclude=drift.diff --exclude=dump.tsv --exclude=oracle-fails.tsv --exclude=report.txt "$CORPUS" "$OUT" > "$OUT/drift.diff"; then
  echo "CORPUS DRIFT: regenerated corpus differs from parity/programs/param-sweep/ (see $OUT/drift.diff)"
  exit 1
fi
echo "corpus matches committed fixtures: $(wc -l < "$OUT/manifest.tsv") variants"

echo "=== [2/4] oracle graphs (reference compiler) ==="
python3 - "$OUT" "$ROOT" <<'PYEOF'
import subprocess, sys
out, root = sys.argv[1], sys.argv[2]
lines = [l.rstrip('\n').split('\t') for l in open(f'{out}/manifest.tsv')]
bad = []
for name, rel in lines:
    dsl = f'{out}/{rel}'
    r = subprocess.run(['node', f'{root}/tools/export-graph.mjs', '--file', dsl, f'{out}/ref/{name}.ref.json'], capture_output=True, text=True)
    if r.returncode != 0:
        bad.append((name, (r.stderr or r.stdout).strip().splitlines()[-1][:200] if (r.stderr or r.stdout).strip() else '?'))
with open(f'{out}/oracle-fails.tsv', 'w') as f:
    for n, e in bad:
        f.write(f'{n}\t{e}\n')
print(f'oracle ok: {len(lines) - len(bad)}, failed: {len(bad)}')
sys.exit(1 if bad else 0)
PYEOF

echo "=== [3/4] C# live-compiler graphs (graphdump, no Unity) ==="
cd "$ROOT"
"$DOTNET" build -c Release tools/graphdump > "$OUT/build.log" 2>&1
awk -F'\t' -v out="$OUT" '{printf "%s/%s\t%s/cs/%s.cs.json\n", out, $2, out, $1}' "$OUT/manifest.tsv" > "$OUT/dump.tsv"
"$DOTNET" tools/graphdump/bin/Release/net8.0/graphdump.dll unity/com.noisemaker.hlsl/Effects "$OUT/dump.tsv" 2>&1 | tee "$OUT/dump.log"

echo "=== [4/4] structural diff (fail-closed) ==="
python3 - "$OUT" <<'PYEOF'
import os, subprocess, sys
out = sys.argv[1]
lines = [l.rstrip('\n').split('\t') for l in open(f'{out}/manifest.tsv')]
ok = fail = missing = 0
fails = []
for name, rel in lines:
    ref, cs = f'{out}/ref/{name}.ref.json', f'{out}/cs/{name}.cs.json'
    if not os.path.exists(ref) or not os.path.exists(cs):
        missing += 1; fails.append((name, 'missing graph')); continue
    r = subprocess.run(['python3', 'parity/graph-diff.py', ref, cs], capture_output=True, text=True)
    if r.returncode == 0: ok += 1
    else:
        fail += 1
        msg = (r.stdout + r.stderr).strip().splitlines()
        fails.append((name, msg[1][:200] if len(msg) > 1 else 'delta'))
with open(f'{out}/report.txt', 'w') as f:
    for n, m in fails:
        f.write(f'{n}\t{m}\n')
print(f'param sweep: {ok} graph-clean, {fail} FAIL, {missing} missing, of {len(lines)} variants')
sys.exit(1 if (fail or missing) else 0)
PYEOF
