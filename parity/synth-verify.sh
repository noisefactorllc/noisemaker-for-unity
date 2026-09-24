#!/usr/bin/env bash
# End-to-end 15-fixture synth parity gate: reference goldens, Unity candidates,
# then fail-closed grading with the repository's measured exception policy.
# Covers the 15 remaining renderable synth effects (bitwise, cellularAutomata, curl,
# gabor, julia, mandelbrot, mnca, modPattern, navierStokes, newton, pattern, polygon,
# reactionDiffusion, roll, subdivide). Together with the 11 fixtures in the root corpus,
# all 26 renderable synth effects are verified for rendered pixel parity.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NODE="${NODE:-node}"
PYTHON="${PYTHON:-python3}"
: "${UNITY:?set UNITY to the Unity editor binary}"
: "${UNITY_PROJECT:?set UNITY_PROJECT to a project embedding com.noisemaker.hlsl}"

MANIFEST="$HERE/programs/synth-manifest.tsv"
EXCEPTIONS="$HERE/programs/synth-exceptions.json"
NM_SYNTH_TMP="$(mktemp -d "${TMPDIR:-/tmp}/nm-unity-synth.XXXXXX")"
trap 'rm -rf -- "$NM_SYNTH_TMP"' EXIT
GOLD="$NM_SYNTH_TMP/gold"
CAND="$NM_SYNTH_TMP/candidate"
RENDER_MANIFEST="$NM_SYNTH_TMP/render.tsv"
UNITY_LOG="$NM_SYNTH_TMP/unity.log"
mkdir -p "$GOLD" "$CAND"

cd "$ROOT"
"$NODE" "$HERE/batch-golden.mjs" "$MANIFEST" "$GOLD" \
  --size 256 --time 0.25 --backend webgl2

awk -F '\t' -v root="$ROOT" -v out="$CAND" '
  NF >= 2 && $1 !~ /^#/ {
    dsl = $2
    if (substr(dsl, 1, 1) != "/") dsl = root "/" dsl
    print dsl "\t" out "/" $1 ".png"
    count++
  }
  END { if (count == 0) exit 2 }
' "$MANIFEST" > "$RENDER_MANIFEST"

"$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" -logFile "$UNITY_LOG" \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
  -nmManifest "$RENDER_MANIFEST" -nmSize 256 -nmTime 0.25

EXPECTED_COUNT="$(wc -l < "$RENDER_MANIFEST" | tr -d ' ')"
if ! grep -Fq "[NMParity] dsl batch done: $EXPECTED_COUNT ok, 0 fail" "$UNITY_LOG"; then
  tail -80 "$UNITY_LOG" >&2
  echo "Unity synth batch did not render the exact manifest successfully" >&2
  exit 1
fi

"$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
  --out "$NM_SYNTH_TMP/report.json" \
  --tolerance 1 --ssim-min 0.92 \
  --manifest "$MANIFEST" --exceptions "$EXCEPTIONS"
