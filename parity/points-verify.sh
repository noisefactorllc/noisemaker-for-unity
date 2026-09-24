#!/usr/bin/env bash
# End-to-end 10-fixture points parity gate: reference goldens, Unity candidates,
# then fail-closed grading with the repository's measured exception policy.
# Runs 60 frames (1 second of simulation runtime at 60 fps) from a clean state
# so particle/agent behaviors (attractors, flocking, slime trails, Lenia solitons,
# DLA growth, hydraulic erosion, particle life) manifest themselves before grading.
# Covers the 10 points effects not in the root corpus (heightGrid is in root).
# Together, all 11 points effects are verified for rendered pixel parity.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NODE="${NODE:-node}"
PYTHON="${PYTHON:-python3}"
: "${UNITY:?set UNITY to the Unity editor binary}"
: "${UNITY_PROJECT:?set UNITY_PROJECT to a project embedding com.noisemaker.hlsl}"

MANIFEST="$HERE/programs/points-manifest.tsv"
EXCEPTIONS="$HERE/programs/points-exceptions.json"
NM_POINTS_TMP="$(mktemp -d "${TMPDIR:-/tmp}/nm-unity-points.XXXXXX")"
trap 'rm -rf -- "$NM_POINTS_TMP"' EXIT
GOLD="$NM_POINTS_TMP/gold"
CAND="$NM_POINTS_TMP/candidate"
RENDER_MANIFEST="$NM_POINTS_TMP/render.tsv"
UNITY_LOG="$NM_POINTS_TMP/unity.log"
mkdir -p "$GOLD" "$CAND"

cd "$ROOT"
"$NODE" "$HERE/batch-golden.mjs" "$MANIFEST" "$GOLD" \
  --size 256 --time 0.25 --frames 60 --backend webgl2

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
  -nmManifest "$RENDER_MANIFEST" -nmSize 256 -nmTime 0.25 -nmFrames 60

EXPECTED_COUNT="$(wc -l < "$RENDER_MANIFEST" | tr -d ' ')"
if ! grep -Fq "[NMParity] dsl batch done: $EXPECTED_COUNT ok, 0 fail" "$UNITY_LOG"; then
  tail -80 "$UNITY_LOG" >&2
  echo "Unity points batch did not render the exact manifest successfully" >&2
  exit 1
fi

"$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
  --out "$NM_POINTS_TMP/report.json" \
  --tolerance 1 --ssim-min 0.50 \
  --manifest "$MANIFEST" --exceptions "$EXCEPTIONS"
