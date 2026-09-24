#!/usr/bin/env bash
# End-to-end 5-fixture render-namespace parity gate: reference goldens, Unity
# candidates, then fail-closed grading with the repository's measured exception
# policy. Runs in two batches because mesh fixtures need a shared OBJ asset:
#   batch A (programs/render-manifest.tsv)        — loopBegin, loopEnd, renderLit3d
#   batch B (programs/render-mesh-manifest.tsv)   — meshLoader, meshRender
#                                                  with --mesh / -nmMesh sphere.obj
# The mesh asset (programs/meshes/sphere.obj) is copied from the pinned
# reference authority's share/meshes/sphere.obj; both sides parse and upload
# the SAME text, so the mesh data textures are identical by construction.
# Together with the root corpus, all renderable render/* effects are verified
# for rendered pixel parity (loopBegin/loopEnd/meshLoader/meshRender/renderLit3d;
# the remaining render/* effects were already covered by the root corpus).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NODE="${NODE:-node}"
PYTHON="${PYTHON:-python3}"
: "${UNITY:?set UNITY to the Unity editor binary}"
: "${UNITY_PROJECT:?set UNITY_PROJECT to a project embedding com.noisemaker.hlsl}"

MANIFEST="$HERE/programs/render-manifest.tsv"
MESH_MANIFEST="$HERE/programs/render-mesh-manifest.tsv"
MESH_OBJ="$HERE/programs/meshes/sphere.obj"
EXCEPTIONS="$HERE/programs/render-exceptions.json"
NM_RENDER_TMP="$(mktemp -d "${TMPDIR:-/tmp}/nm-unity-render.XXXXXX")"
trap 'rm -rf -- "$NM_RENDER_TMP"' EXIT
GOLD="$NM_RENDER_TMP/gold"
CAND="$NM_RENDER_TMP/candidate"
GOLD_MESH="$NM_RENDER_TMP/gold-mesh"
CAND_MESH="$NM_RENDER_TMP/candidate-mesh"
RENDER_MANIFEST="$NM_RENDER_TMP/render.tsv"
MESH_RENDER_MANIFEST="$NM_RENDER_TMP/render-mesh.tsv"
UNITY_LOG="$NM_RENDER_TMP/unity.log"
UNITY_MESH_LOG="$NM_RENDER_TMP/unity-mesh.log"
mkdir -p "$GOLD" "$CAND" "$GOLD_MESH" "$CAND_MESH"

cd "$ROOT"
"$NODE" "$HERE/batch-golden.mjs" "$MANIFEST" "$GOLD" \
  --size 256 --time 0.25 --backend webgl2
"$NODE" "$HERE/batch-golden.mjs" "$MESH_MANIFEST" "$GOLD_MESH" \
  --size 256 --time 0.25 --backend webgl2 --mesh "$MESH_OBJ"

awk -F '\t' -v root="$ROOT" -v out="$CAND" '
  NF >= 2 && $1 !~ /^#/ {
    dsl = $2
    if (substr(dsl, 1, 1) != "/") dsl = root "/" dsl
    print dsl "\t" out "/" $1 ".png"
    count++
  }
  END { if (count == 0) exit 2 }
' "$MANIFEST" > "$RENDER_MANIFEST"

awk -F '\t' -v root="$ROOT" -v out="$CAND_MESH" '
  NF >= 2 && $1 !~ /^#/ {
    dsl = $2
    if (substr(dsl, 1, 1) != "/") dsl = root "/" dsl
    print dsl "\t" out "/" $1 ".png"
    count++
  }
  END { if (count == 0) exit 2 }
' "$MESH_MANIFEST" > "$MESH_RENDER_MANIFEST"

"$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" -logFile "$UNITY_LOG" \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
  -nmManifest "$RENDER_MANIFEST" -nmSize 256 -nmTime 0.25

"$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" -logFile "$UNITY_MESH_LOG" \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
  -nmManifest "$MESH_RENDER_MANIFEST" -nmSize 256 -nmTime 0.25 \
  -nmMesh "$MESH_OBJ"

EXPECTED_COUNT="$(wc -l < "$RENDER_MANIFEST" | tr -d ' ')"
if ! grep -Fq "[NMParity] dsl batch done: $EXPECTED_COUNT ok, 0 fail" "$UNITY_LOG"; then
  tail -80 "$UNITY_LOG" >&2
  echo "Unity render batch did not render the exact manifest successfully" >&2
  exit 1
fi
EXPECTED_MESH_COUNT="$(wc -l < "$MESH_RENDER_MANIFEST" | tr -d ' ')"
if ! grep -Fq "[NMParity] dsl batch done: $EXPECTED_MESH_COUNT ok, 0 fail" "$UNITY_MESH_LOG"; then
  tail -80 "$UNITY_MESH_LOG" >&2
  echo "Unity mesh batch did not render the exact manifest successfully" >&2
  exit 1
fi
if ! grep -Eq "NMParity. mesh0 loaded from $MESH_OBJ: [1-9][0-9]* vertices" "$UNITY_MESH_LOG"; then
  tail -40 "$UNITY_MESH_LOG" >&2
  echo "Unity mesh batch did not load the shared OBJ (or loaded zero vertices)" >&2
  exit 1
fi

"$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
  --out "$NM_RENDER_TMP/report.json" \
  --tolerance 1 --ssim-min 0.9999 \
  --manifest "$MANIFEST" --exceptions "$EXCEPTIONS"

# Merge the mesh batch into the same grading pass so one exceptions file covers
# both (the grader rejects exception cases outside the compared manifest).
cp "$GOLD_MESH"/*.golden.png "$GOLD"/
cp "$CAND_MESH"/*.png "$CAND"/
cat "$MANIFEST" "$MESH_MANIFEST" > "$NM_RENDER_TMP/combined.tsv"

"$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
  --out "$NM_RENDER_TMP/report-combined.json" \
  --tolerance 1 --ssim-min 0.9999 \
  --manifest "$NM_RENDER_TMP/combined.tsv" --exceptions "$EXCEPTIONS"
