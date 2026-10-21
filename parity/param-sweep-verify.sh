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
if ! diff -r --exclude=ref --exclude=cs --exclude='*.log' --exclude=drift.diff --exclude=dump.tsv --exclude=oracle-fails.tsv --exclude=report.txt --exclude=results.tsv --exclude='pixel-exceptions-*.json' --exclude='pixel-reference-blocked.tsv' "$CORPUS" "$OUT" > "$OUT/drift.diff"; then
  echo "CORPUS DRIFT: regenerated corpus differs from parity/programs/param-sweep/ (see $OUT/drift.diff)"
  exit 1
fi
echo "corpus matches committed fixtures: $(wc -l < "$OUT/manifest.tsv") variants"

echo "=== [2/4] oracle graphs (reference compiler) ==="
# One batch process bootstraps the reference once and compiles every variant;
# the per-variant command, verdicts and fail-closed aggregation are unchanged.
awk -F'\t' -v out="$OUT" '{ printf "%s/ref/%s.ref.json\t%s/%s\t%s\n", out, $1, out, $2, $1 }' \
  "$OUT/manifest.tsv" > "$OUT/oracle.tsv"
node "$ROOT/tools/export-graph.mjs" --batch "$OUT/oracle.tsv" --fails "$OUT/oracle-fails.tsv" \
  > "$OUT/oracle.log" 2>&1 || { cat "$OUT/oracle.log"; exit 1; }
grep -E '^ORACLE FAIL' "$OUT/oracle.log" || true
grep -E '^oracle: ' "$OUT/oracle.log"

echo "=== [3/4] C# live-compiler graphs (graphdump, no Unity) ==="
cd "$ROOT"
"$DOTNET" build -c Release tools/graphdump > "$OUT/build.log" 2>&1
awk -F'\t' -v out="$OUT" '{printf "%s/%s\t%s/cs/%s.cs.json\n", out, $2, out, $1}' "$OUT/manifest.tsv" > "$OUT/dump.tsv"
"$DOTNET" tools/graphdump/bin/Release/net8.0/graphdump.dll unity/com.noisemaker.hlsl/Effects "$OUT/dump.tsv" 2>&1 | tee "$OUT/dump.log"

echo "=== [4/4] structural diff (fail-closed) ==="
# One batch process diffs every variant pair in-process; the per-variant
# command, verdicts and fail-closed aggregation are unchanged.
cd "$ROOT"
awk -F'\t' -v out="$OUT" '{ printf "%s/ref/%s.ref.json\t%s/cs/%s.cs.json\t%s\n", out, $1, out, $1, $1 }' \
  "$OUT/manifest.tsv" > "$OUT/diff.tsv"
python3 parity/graph-diff.py --batch "$OUT/diff.tsv" --results "$OUT/results.raw.tsv" \
  > "$OUT/diff.log" 2>&1 || { cat "$OUT/diff.log"; exit 1; }
grep -E '^GRAPH FAIL' "$OUT/diff.log" || true
ok="$(awk -F'\t' '$2 == "PASS"' "$OUT/results.raw.tsv" | wc -l | tr -d ' ')"
fail="$(awk -F'\t' '$2 == "FAIL"' "$OUT/results.raw.tsv" | wc -l | tr -d ' ')"
missing="$(awk -F'\t' '$2 == "MISSING"' "$OUT/results.raw.tsv" | wc -l | tr -d ' ')"
{
  printf '# param-sweep per-variant results (fail-closed gate)\n'
  printf '# variants: %s  graph-clean: %s  FAIL: %s  missing: %s\n' "$(wc -l < "$OUT/manifest.tsv" | tr -d ' ')" "$ok" "$fail" "$missing"
  cat "$OUT/results.raw.tsv"
} > "$OUT/results.tsv"
awk -F'\t' '$2 != "PASS" { print $1 "\t" ($3 != "" ? $3 : $2) }' "$OUT/results.raw.tsv" > "$OUT/report.txt"
echo "param sweep: $ok graph-clean, $fail FAIL, $missing missing, of $((ok + fail + missing)) variants"
[ "$fail" -eq 0 ] && [ "$missing" -eq 0 ] || exit 1
