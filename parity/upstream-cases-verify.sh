#!/usr/bin/env bash
# Pixel gate for all 148 noisemaker@d0ed94ae effect parity cases at the
# GAP-030 capture settings. Stage modes allow WebGL2 and Unity on separate hosts.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CORPUS="$HERE/programs/upstream-cases"
MANIFEST="$CORPUS/manifest.tsv"
NODE="${NODE:-node}"
PYTHON="${PYTHON:-python3}"
STAGE=all
if [ "${1:-}" = --stage ]; then
  case "${2:-}" in
    goldens|unity|grade) STAGE="$2"; shift 2 ;;
    *) echo "use --stage goldens|unity|grade" >&2; exit 2 ;;
  esac
fi
WORK="${1:?provide a work directory}"
: "${NM_REFERENCE_ROOT:?set NM_REFERENCE_ROOT to pinned noisemaker checkout}"
REFERENCE_SHA=d0ed94ae19cca7328bc7d6b28902712a0838e1a9
if [ "$(git -C "$NM_REFERENCE_ROOT" rev-parse HEAD)" != "$REFERENCE_SHA" ]; then
  echo "reference checkout must be noisemaker@$REFERENCE_SHA" >&2
  exit 2
fi
reference_status="$(git -C "$NM_REFERENCE_ROOT" status --porcelain --untracked-files=all)" \
  || { echo "cannot inspect reference checkout status" >&2; exit 2; }
if [ -n "$reference_status" ]; then
  echo "reference checkout must be clean at noisemaker@$REFERENCE_SHA" >&2
  exit 2
fi

# Fail closed if a fixture is missing, extra, or differs from the pinned
# upstream parity-case DSL or texture inputs. The cube is the pinned meshLoader input.
"$PYTHON" - "$ROOT" "$NM_REFERENCE_ROOT" <<'PY'
import json
import sys
from pathlib import Path

root, ref = map(Path, sys.argv[1:])
corpus = root / 'parity/programs/upstream-cases'
sources = sorted((ref / 'shaders/effects').glob('*/*/parity-case.json'))
rows = [line.split('\t') for line in (corpus / 'manifest.tsv').read_text().splitlines()]
assert len(sources) == len(rows) == 148, 'upstream case count changed'
expected = {f'{p.parent.parent.name}__{p.parent.name}': p for p in sources}
assert len(expected) == 148 and len({row[0] for row in rows}) == 148
assert {p.name for p in corpus.glob('*.dsl')} == {
    f'{row[0]}.dsl' for row in rows}, 'fixture DSL set differs from manifest'
for name, path in rows:
    assert name in expected, f'unknown case {name}'
    assert path == f'parity/programs/upstream-cases/{name}.dsl', name
    case = json.loads(expected[name].read_text())
    assert (root / path).read_text() == case['dsl'], name
    textures = (root / path).with_suffix('.textures.json')
    assert (json.loads(textures.read_text()) if textures.is_file() else None) == case.get('textureInputs'), name
assert (corpus / 'cube.obj').read_bytes() == (ref / 'share/meshes/cube.obj').read_bytes()
assert (corpus / 'flow60-manifest.tsv').read_text() == (
    'points__flow\tparity/programs/upstream-cases/points__flow.dsl\n')
print('148 pinned upstream cases and cube mesh verified')
PY

if [ "$STAGE" = unity ] || [ "$STAGE" = all ]; then
  : "${UNITY:?set UNITY to the Unity editor binary}"
  : "${UNITY_PROJECT:?set UNITY_PROJECT to a project embedding com.noisemaker.hlsl}"
fi

mkdir -p "$WORK"
for mode in untiled tiled; do
  GOLD="$WORK/gold-$mode"
  CAND="$WORK/candidate-$mode"
  mkdir -p "$GOLD" "$CAND"
  if [ "$STAGE" = goldens ] || [ "$STAGE" = all ]; then
    cd "$ROOT"
    if [ "$mode" = tiled ]; then
      "$NODE" "$HERE/batch-golden.mjs" "$MANIFEST" "$GOLD" \
        --size 128 --time 0.25 --frames 8 --backend webgl2 \
        --mesh "$CORPUS/cube.obj" \
        --tile-x 37 --tile-y 23 --full-width 256 --full-height 256 --render-scale 1
    else
      "$NODE" "$HERE/batch-golden.mjs" "$MANIFEST" "$GOLD" \
        --size 128 --time 0.25 --frames 8 --backend webgl2 \
        --mesh "$CORPUS/cube.obj"
    fi
  fi

  if [ "$STAGE" = unity ] || [ "$STAGE" = all ]; then
    RENDER_MANIFEST="$WORK/unity-$mode.tsv"
    awk -F '\t' -v root="$ROOT" -v out="$CAND" \
      '{print root "/" $2 "\t" out "/" $1 ".png"}' "$MANIFEST" > "$RENDER_MANIFEST"
    if [ "$mode" = tiled ]; then
      "$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" \
        -logFile "$WORK/unity-$mode.log" \
        -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
        -nmManifest "$RENDER_MANIFEST" -nmSize 128 -nmTime 0.25 -nmFrames 8 \
        -nmMesh "$CORPUS/cube.obj" \
        -nmTileX 37 -nmTileY 23 -nmFullWidth 256 -nmFullHeight 256 -nmRenderScale 1
    else
      "$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" \
        -logFile "$WORK/unity-$mode.log" \
        -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
        -nmManifest "$RENDER_MANIFEST" -nmSize 128 -nmTime 0.25 -nmFrames 8 \
        -nmMesh "$CORPUS/cube.obj"
    fi
    if ! grep -Fq '[NMParity] dsl batch done: 148 ok, 0 fail' "$WORK/unity-$mode.log"; then
      tail -80 "$WORK/unity-$mode.log" >&2
      exit 1
    fi
  fi

  if [ "$STAGE" = grade ] || [ "$STAGE" = all ]; then
    "$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
      --out "$WORK/report-$mode.json" --tolerance 1 --ssim-min 0 \
      --manifest "$MANIFEST" --exceptions "$CORPUS/exceptions-$mode.json"
  fi
done

# The original GAP-030 Flow miss grew over 60 updates. Keep that longer run
# alongside the 148-case eight-frame gate so the canvas-stride fix is covered.
FLOW60_MANIFEST="$CORPUS/flow60-manifest.tsv"
FLOW60_GOLD="$WORK/gold-flow60"
FLOW60_CAND="$WORK/candidate-flow60"
mkdir -p "$FLOW60_GOLD" "$FLOW60_CAND"
if [ "$STAGE" = goldens ] || [ "$STAGE" = all ]; then
  cd "$ROOT"
  "$NODE" "$HERE/batch-golden.mjs" "$FLOW60_MANIFEST" "$FLOW60_GOLD" \
    --size 128 --time 0.25 --frames 60 --backend webgl2
fi
if [ "$STAGE" = unity ] || [ "$STAGE" = all ]; then
  FLOW60_RENDER_MANIFEST="$WORK/unity-flow60.tsv"
  printf '%s\t%s\n' "$CORPUS/points__flow.dsl" "$FLOW60_CAND/points__flow.png" \
    > "$FLOW60_RENDER_MANIFEST"
  "$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" \
    -logFile "$WORK/unity-flow60.log" \
    -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
    -nmManifest "$FLOW60_RENDER_MANIFEST" -nmSize 128 -nmTime 0.25 -nmFrames 60
  if ! grep -Fq '[NMParity] dsl batch done: 1 ok, 0 fail' "$WORK/unity-flow60.log"; then
    tail -80 "$WORK/unity-flow60.log" >&2
    exit 1
  fi
fi
if [ "$STAGE" = grade ] || [ "$STAGE" = all ]; then
  "$PYTHON" "$HERE/batch-compare.py" "$FLOW60_GOLD" "$FLOW60_CAND" \
    --out "$WORK/report-flow60.json" --tolerance 1 --ssim-min 0 \
    --manifest "$FLOW60_MANIFEST" --exceptions "$CORPUS/flow60-exceptions.json"
fi

# Exercise the tile-dependent sampling and cell-size boundaries changed upstream.
TILE_SYNC="$HERE/programs/tile-sync/manifest.tsv"
for mode in scaled origin shifted equal-shifted zoom-budget glyph-cap; do
  CASE_MANIFEST="$TILE_SYNC"
  FULL=512
  TILE_X=0
  TILE_Y=0
  SCALE=3
  SIZE=128
  case "$mode" in
    scaled) FULL=128 ;;
    shifted) TILE_X=37; TILE_Y=23 ;;
    equal-shifted) FULL=128; TILE_X=37; TILE_Y=23 ;;
    zoom-budget)
      FULL=4096; TILE_X=256; TILE_Y=256; SCALE=1; SIZE=512
      CASE_MANIFEST="$HERE/programs/tile-sync/zoom-budget.tsv"
      ;;
    glyph-cap)
      SCALE=32
      CASE_MANIFEST="$WORK/glyph-cap.tsv"
      awk -F '\t' '$1 == "glyphMap"' "$TILE_SYNC" > "$CASE_MANIFEST"
      ;;
  esac
  GOLD="$WORK/gold-$mode"
  CAND="$WORK/candidate-$mode"
  mkdir -p "$GOLD" "$CAND"
  if [ "$STAGE" = goldens ] || [ "$STAGE" = all ]; then
    cd "$ROOT"
    "$NODE" "$HERE/batch-golden.mjs" "$CASE_MANIFEST" "$GOLD" \
      --size "$SIZE" --time 0.25 --frames 8 --backend webgl2 \
      --tile-x "$TILE_X" --tile-y "$TILE_Y" \
      --full-width "$FULL" --full-height "$FULL" --render-scale "$SCALE"
  fi
  if [ "$STAGE" = unity ] || [ "$STAGE" = all ]; then
    RENDER_MANIFEST="$WORK/unity-$mode.tsv"
    awk -F '\t' -v root="$ROOT" -v out="$CAND" \
      '{print root "/" $2 "\t" out "/" $1 ".png"}' "$CASE_MANIFEST" > "$RENDER_MANIFEST"
    "$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" \
      -logFile "$WORK/unity-$mode.log" \
      -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
      -nmManifest "$RENDER_MANIFEST" -nmSize "$SIZE" -nmTime 0.25 -nmFrames 8 \
      -nmTileX "$TILE_X" -nmTileY "$TILE_Y" \
      -nmFullWidth "$FULL" -nmFullHeight "$FULL" -nmRenderScale "$SCALE"
    COUNT="$(wc -l < "$CASE_MANIFEST" | tr -d ' ')"
    if ! grep -Fq "[NMParity] dsl batch done: $COUNT ok, 0 fail" "$WORK/unity-$mode.log"; then
      tail -80 "$WORK/unity-$mode.log" >&2
      exit 1
    fi
  fi
  if [ "$STAGE" = grade ] || [ "$STAGE" = all ]; then
    "$PYTHON" "$HERE/batch-compare.py" "$GOLD" "$CAND" \
      --out "$WORK/report-$mode.json" --tolerance 1 --ssim-min 0.9999 \
      --manifest "$CASE_MANIFEST"
  fi
done
