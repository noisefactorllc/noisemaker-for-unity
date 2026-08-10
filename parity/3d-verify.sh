#!/usr/bin/env bash
# End-to-end nine-fixture 3D parity gate: reference goldens, Unity candidates,
# then exact-universe grading with the repository's measured exception policy.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NODE="${NODE:-node}"
PYTHON="${PYTHON:-python3}"
: "${UNITY:?set UNITY to the Unity editor binary}"
: "${UNITY_PROJECT:?set UNITY_PROJECT to a project embedding com.noisemaker.hlsl}"

MANIFEST="$HERE/programs/3d-manifest.tsv"
EXCEPTIONS="$HERE/programs/3d-exceptions.json"
NM_3D_TMP="$(mktemp -d "${TMPDIR:-/tmp}/nm-unity-3d.XXXXXX")"
trap 'rm -rf -- "$NM_3D_TMP"' EXIT
GOLD="$NM_3D_TMP/gold"
CAND="$NM_3D_TMP/candidate"
RENDER_MANIFEST="$NM_3D_TMP/render.tsv"
UNITY_LOG="$NM_3D_TMP/unity.log"
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
  echo "Unity 3D batch did not render the exact manifest successfully" >&2
  exit 1
fi

"$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
  --out "$NM_3D_TMP/report.json" \
  --tolerance 2 --ssim-min 0.98 \
  --manifest "$MANIFEST" --exceptions "$EXCEPTIONS"
