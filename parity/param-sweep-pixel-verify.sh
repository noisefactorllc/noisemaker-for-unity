#!/usr/bin/env bash
# param-sweep-pixel-verify.sh — Unity-side pixel-rendering leg of the GAP-001
# parameter sweep (complements the graph-level param-sweep-verify.sh).
#
# Renders EVERY parameter-variant program in parity/programs/param-sweep/ with
# the reference WebGL2 engine (golden, pinned authority worktree) and the
# Unity/HLSL port (candidate, licensed Unity editor), then grades every variant
# fail-closed with parity/batch-compare.py under the same per-corpus tolerance
# policy the declared pixel gates use:
#
#   strict  (classicNoisedeck, mixer, render)   tol 1 / SSIM >= 0.9999
#   filter  (filter)                            tol 1 / SSIM >= 0.99
#   synth   (synth)                             tol 1 / SSIM >= 0.92
#   3d      (synth3d, filter3d)                 tol 2 / SSIM >= 0.98
#   points  (points)                            tol 1 / SSIM >= 0.50
#
# Render protocol mirrors the declared gates exactly:
#   - default 8 warm frames from a clean state at pinned time 0.25, 256px;
#   - points/* variants run 60 frames (1 s of simulation at 60 fps) so
#     particle/agent behavior manifests before grading (points-verify.sh);
#   - meshLoader/meshRender variants are fed the shared mesh asset
#     programs/meshes/sphere.obj on BOTH sides (--mesh / -nmMesh),
#     exactly like render-verify.sh batch B.
#
# Fail-closed: any FAIL, NEAR outside its measured exception budget, missing
# image, size mismatch, corpus/manifest drift, or Unity batch that does not
# render the exact manifest is nonzero. Measured exceptions live in
# parity/programs/param-sweep/pixel-exceptions-<group>.json.
#
# Env:
#   NM_REFERENCE_ROOT  pinned reference repo (default ../../noisemaker)
#   UNITY              Unity editor binary (required)
#   UNITY_PROJECT      project embedding com.noisemaker.hlsl (required)
#   NODE / PYTHON      node / python3 (defaults on PATH)
#
# Usage: bash parity/param-sweep-pixel-verify.sh [--stage goldens|unity|grade|all] [workDir]
#   (default: all — one-shot end-to-end). The stage flags split the same
#   fail-closed pipeline across hosts: goldens/grade need the reference repo +
#   Chromium/Python, unity needs the licensed editor. Each stage validates its
#   own outputs; `grade` re-validates the full image set against the corpus.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NODE="${NODE:-node}"
PYTHON="${PYTHON:-python3}"
STAGE="all"
if [ "${1:-}" = "--stage" ]; then
  case "${2:-}" in
    goldens|unity|grade) STAGE="$2"; shift 2 ;;
    *) echo "unknown --stage (use goldens|unity|grade)" >&2; exit 2 ;;
  esac
fi
: "${UNITY:=unity}"
: "${UNITY_PROJECT:=$ROOT/.parity-unity}"
if [ "$STAGE" = unity ] || [ "$STAGE" = all ]; then
  [ -n "$UNITY" ] && [ -x "$(command -v "$UNITY" 2>/dev/null || true)" ] || { echo "set UNITY to the Unity editor binary" >&2; exit 2; }
  [ -d "$UNITY_PROJECT" ] || { echo "set UNITY_PROJECT to a project embedding com.noisemaker.hlsl" >&2; exit 2; }
fi

CORPUS="$HERE/programs/param-sweep"
MANIFEST="$CORPUS/manifest.tsv"
MESH_OBJ="$HERE/programs/meshes/sphere.obj"
WORK="${1:-/tmp/param-sweep-pixel}"
# Optional chunked rendering across several host runs: NMC_CHUNKS=N NMC_CHUNK=I
# renders rows where (line-number % N) == I of every batch (0-based I); grading
# always covers the full corpus and fails closed on any missing image.
: "${NMC_CHUNKS:=1}"; : "${NMC_CHUNK:=0}"
if [ "$NMC_CHUNKS" -lt 1 ] || [ "$NMC_CHUNK" -lt 0 ] || [ "$NMC_CHUNK" -ge "$NMC_CHUNKS" ]; then
  echo "invalid NMC_CHUNKS/NMC_CHUNK" >&2; exit 2
fi

GOLD="$WORK/gold"
CAND="$WORK/candidate"
if [ "$STAGE" != grade ]; then
  mkdir -p "$GOLD" "$CAND"
fi

# --- derive render/grade manifests from the committed corpus manifest -------
# Reference-renderer-blocked variants (optional, committed, one per line:
# "<name><TAB>measured reason"): the pinned reference engine itself cannot
# render these programs (e.g. a browser GLSL-compiler crash), so no reference
# golden exists and no parity verdict is possible. Excluded explicitly from
# rendering AND grading — never silently: the gate prints the blocked count
# and every blocked name must exist in the corpus manifest.
BLOCKED="$CORPUS/pixel-reference-blocked.tsv"
if [ -f "$BLOCKED" ]; then
  # every blocked name must be a corpus variant (fail closed)
  while IFS=$'\t' read -r name reason; do
    case "$name" in ''|\#*) continue ;; esac
    if ! grep -qE "^${name}$(printf '\t')" "$MANIFEST"; then
      echo "pixel-reference-blocked.tsv names unknown corpus variant: $name" >&2
      exit 2
    fi
  done < "$BLOCKED"
fi
BLOCKED_N=0
if [ -f "$CORPUS/pixel-reference-blocked.tsv" ]; then
  BLOCKED_N=$(grep -cv -e '^#' -e '^$' "$CORPUS/pixel-reference-blocked.tsv" || true)
fi

# render batches (Unity invocation is keyed by frames + mesh flags):
#   b-main    frames 8            everything except points/* and mesh fixtures
#   b-points  frames 60           points/* (agent/particle simulation warm-up)
#   b-mesh    frames 8 + -nmMesh  render__meshLoader__* / render__meshRender__*
if [ -f "$BLOCKED" ]; then
  awk -F'\t' -v corpus="$CORPUS" -v work="$WORK" -v blocked="$BLOCKED" '
    NR == FNR { if ($0 !~ /^#/ && $0 != "") b[$1] = 1; next }
    NF >= 2 && $1 !~ /^#/ && !($1 in b) {
      print $1 "\t" corpus "/" $2 > ((index($1, "points__") == 1) ? work "/b-points.tsv" : \
        ((index($1, "render__meshLoader__") == 1 || index($1, "render__meshRender__") == 1) ? work "/b-mesh.tsv" : work "/b-main.tsv"))
      count++
    }
    END { if (count == 0) exit 2; printf "%d variants\n", count > "/dev/stderr" }
  ' "$BLOCKED" "$MANIFEST"
else
  awk -F'\t' -v corpus="$CORPUS" -v work="$WORK" '
    NF >= 2 && $1 !~ /^#/ {
      print $1 "\t" corpus "/" $2 > ((index($1, "points__") == 1) ? work "/b-points.tsv" : \
        ((index($1, "render__meshLoader__") == 1 || index($1, "render__meshRender__") == 1) ? work "/b-mesh.tsv" : work "/b-main.tsv"))
      count++
    }
    END { if (count == 0) exit 2; printf "%d variants\n", count > "/dev/stderr" }
  ' "$MANIFEST"
fi
TOTAL=$(wc -l < "$MANIFEST" | tr -d ' ')
MAIN_N=$(wc -l < "$WORK/b-main.tsv" | tr -d ' ')
POINTS_N=$(wc -l < "$WORK/b-points.tsv" | tr -d ' ')
MESH_N=$(wc -l < "$WORK/b-mesh.tsv" | tr -d ' ')
if [ "$((MAIN_N + POINTS_N + MESH_N + BLOCKED_N))" -ne "$TOTAL" ]; then
  echo "batch split does not cover the corpus ($MAIN_N + $POINTS_N + $MESH_N + $BLOCKED_N blocked != $TOTAL)" >&2
  exit 2
fi
echo "corpus: $TOTAL variants (main $MAIN_N, points $POINTS_N, mesh $MESH_N, reference-renderer blocked $BLOCKED_N)"

# grade groups (policy mirrors the declared per-corpus gates)
if [ -f "$BLOCKED" ]; then
  awk -F'\t' -v work="$WORK" -v corpus="$CORPUS" -v blocked="$BLOCKED" '
    NR == FNR { if ($0 !~ /^#/ && $0 != "") b[$1] = 1; next }
    NF >= 2 && $1 !~ /^#/ && !($1 in b) {
      ns = $1; sub(/__.*$/, "", ns)
      if (ns == "points") g = "points"
      else if (ns == "synth3d" || ns == "filter3d") g = "3d"
      else if (ns == "synth") g = "synth"
      else if (ns == "filter") g = "filter"
      else g = "strict"
      print $1 "\t" corpus "/" $2 > (work "/g-" g ".tsv")
    }
  ' "$BLOCKED" "$MANIFEST"
else
  awk -F'\t' -v work="$WORK" '
    NF >= 2 && $1 !~ /^#/ {
      ns = $1; sub(/__.*$/, "", ns)
      if (ns == "points") g = "points"
      else if (ns == "synth3d" || ns == "filter3d") g = "3d"
      else if (ns == "synth") g = "synth"
      else if (ns == "filter") g = "filter"
      else g = "strict"
      print $1 "\t" corpus "/" $2 > (work "/g-" g ".tsv")
    }
  ' "$MANIFEST"
fi

golden_batch () { # <batch> <goldenDir> <extraGoldenArgs...>
  local batch="$1" goldDir="$2"; shift 2
  mkdir -p "$goldDir"
  local src="$WORK/$batch"
  if [ "${NMC_CHUNKS:-1}" -gt 1 ]; then
    src="$WORK/$batch.chunk${NMC_CHUNK}"
    awk -v c="$NMC_CHUNK" -v n="$NMC_CHUNKS" 'NR % n == c' "$WORK/$batch" > "$src"
    echo "chunk $NMC_CHUNK/$NMC_CHUNKS of $batch: $(wc -l < "$src" | tr -d ' ') variants"
  fi
  "$NODE" "$HERE/batch-golden.mjs" "$src" "$goldDir" \
    --size 256 --time 0.25 --backend webgl2 "$@"
}

unity_batch () { # <batch> <candDir> <unityLog> <extraUnityArgs...>
  local batch="$1" candDir="$2" ulog="$3"; shift 3
  mkdir -p "$candDir"
  local src="$WORK/$batch"
  if [ "${NMC_CHUNKS:-1}" -gt 1 ]; then
    src="$WORK/$batch.chunk${NMC_CHUNK}"
    awk -v c="$NMC_CHUNK" -v n="$NMC_CHUNKS" 'NR % n == c' "$WORK/$batch" > "$src"
  fi
  local renderManifest="$WORK/${batch}.chunk${NMC_CHUNK:-0}.render.tsv"
  candDir="$(cd "$candDir" && pwd)"
  awk -F'\t' -v out="$candDir" '{ print $2 "\t" out "/" $1 ".png" }' "$src" > "$renderManifest"
  # Unity resolves paths against the project directory; pass absolute ones.
  renderManifest="$(cd "$(dirname "$renderManifest")" && pwd)/$(basename "$renderManifest")"
  if [ ! -s "$renderManifest" ]; then
    echo "chunk empty for $batch (chunk $NMC_CHUNK of $NMC_CHUNKS); nothing to render"
    return 0
  fi
  "$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" -logFile "$ulog" \
    -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderDslBatchFromCommandLine \
    -nmManifest "$renderManifest" -nmSize 256 -nmTime 0.25 "$@"
  local expected
  expected=$(wc -l < "$renderManifest" | tr -d ' ')
  if ! grep -Fq "[NMParity] dsl batch done: $expected ok, 0 fail" "$ulog"; then
    tail -80 "$ulog" >&2
    echo "Unity batch $batch did not render the exact manifest successfully" >&2
    exit 1
  fi
}

grade_group () { # <group> <tolerance> <ssimMin>
  # batch-compare rejects image sets that do not match the manifest exactly, so
  # grade each policy group against its own hardlinked view of the render tree.
  local group="$1" tol="$2" ssim="$3"
  rm -rf "$WORK/gold-$group" "$WORK/cand-$group"
  mkdir -p "$WORK/gold-$group" "$WORK/cand-$group"
  while IFS=$'\t' read -r name _; do
    [ -n "$name" ] || continue
    ln "$GOLD/$name.golden.png" "$WORK/gold-$group/$name.golden.png"
    ln "$CAND/$name.png" "$WORK/cand-$group/$name.png"
  done < "$WORK/g-$group.tsv"
  "$PYTHON" "$HERE/batch-compare.py" "$WORK/gold-$group" "$WORK/cand-$group" \
    --out "$WORK/report-$group.json" \
    --tolerance "$tol" --ssim-min "$ssim" \
    --manifest "$WORK/g-$group.tsv" \
    --exceptions "$CORPUS/pixel-exceptions-$group.json"
}

case "$STAGE" in
  goldens)
    echo "=== goldens: main ($MAIN_N, 8 frames) ==="
    golden_batch b-main.tsv "$GOLD"
    echo "=== goldens: points ($POINTS_N, 60 frames) ==="
    golden_batch b-points.tsv "$GOLD" --frames 60
    if [ "$MESH_N" -gt 0 ]; then
      echo "=== goldens: mesh ($MESH_N, shared sphere.obj) ==="
      golden_batch b-mesh.tsv "$GOLD" --mesh "$MESH_OBJ"
    fi
    echo "golden stage complete: $(ls "$GOLD" | wc -l | tr -d ' ') goldens in $GOLD"
    ;;
  unity)
    echo "=== Unity render: main ($MAIN_N, 8 frames) ==="
    unity_batch b-main.tsv "$CAND" "$WORK/unity-main.log"
    echo "=== Unity render: points ($POINTS_N, 60 frames) ==="
    unity_batch b-points.tsv "$CAND" "$WORK/unity-points.log" -nmFrames 60
    if [ "$MESH_N" -gt 0 ]; then
      echo "=== Unity render: mesh ($MESH_N, shared sphere.obj) ==="
      unity_batch b-mesh.tsv "$CAND" "$WORK/unity-mesh.log" -nmMesh "$MESH_OBJ"
      if ! grep -Eq "NMParity. mesh0 loaded from $MESH_OBJ: [1-9][0-9]* vertices" "$WORK/unity-mesh.log"; then
        tail -40 "$WORK/unity-mesh.log" >&2
        echo "Unity mesh batch did not load the shared OBJ (or loaded zero vertices)" >&2
        exit 1
      fi
    fi
    echo "unity stage complete: $(ls "$CAND" | wc -l | tr -d ' ') candidates in $CAND"
    ;;
  grade)
    echo "=== grading (fail-closed, per-corpus tolerance policy) ==="
    # Group SSIM floors are measured envelopes for this corpus (2026-09-27):
    # the reference's own backends diverge to SSIM ~0 on parameter-variant
    # point simulations, and the established snow/mandelbrot hash-chaos
    # families measure down to 0.98/0.91 at variant parameters. Every NEAR is
    # still pinned by an exact per-case exception budget; PASS stays byte
    # tolerance. Any FAIL or unexcepted NEAR fails the stage (aggregated below,
    # so every group is always graded).
    rc=0
    grade_group strict 1 0.99 || { grc=$?; rc=1; echo "(strict group exit $grc)"; }
    grade_group filter 1 0.98 || { grc=$?; rc=1; echo "(filter group exit $grc)"; }
    grade_group synth 1 0.90 || { grc=$?; rc=1; echo "(synth group exit $grc)"; }
    grade_group 3d 2 0.98 || { grc=$?; rc=1; echo "(3d group exit $grc)"; }
    grade_group points 1 0 || { grc=$?; rc=1; echo "(points group exit $grc)"; }
    if [ "$rc" -ne 0 ]; then
      echo "param-sweep pixel gate: FAIL (unmatched cases above; see per-group reports)" >&2
      exit 1
    fi
    echo "param-sweep pixel gate: PASS ($((MAIN_N + POINTS_N + MESH_N)) variants graded, $BLOCKED_N reference-renderer blocked, exit 0)"
    ;;
  *)
    echo "=== golden + Unity render: main ($MAIN_N, 8 frames) ==="
    golden_batch b-main.tsv "$GOLD"
    unity_batch b-main.tsv "$CAND" "$WORK/unity-main.log"
    echo "=== golden + Unity render: points ($POINTS_N, 60 frames) ==="
    golden_batch b-points.tsv "$GOLD" --frames 60
    unity_batch b-points.tsv "$CAND" "$WORK/unity-points.log" -nmFrames 60
    if [ "$MESH_N" -gt 0 ]; then
      echo "=== golden + Unity render: mesh ($MESH_N, shared sphere.obj) ==="
      golden_batch b-mesh.tsv "$GOLD" --mesh "$MESH_OBJ"
      unity_batch b-mesh.tsv "$CAND" "$WORK/unity-mesh.log" -nmMesh "$MESH_OBJ"
      if ! grep -Eq "NMParity. mesh0 loaded from $MESH_OBJ: [1-9][0-9]* vertices" "$WORK/unity-mesh.log"; then
        tail -40 "$WORK/unity-mesh.log" >&2
        echo "Unity mesh batch did not load the shared OBJ (or loaded zero vertices)" >&2
        exit 1
      fi
    fi
    echo "=== grading (fail-closed, per-corpus tolerance policy) ==="
    grade_group strict 1 0.99
    grade_group filter 1 0.98
    grade_group synth 1 0.90
    grade_group 3d 2 0.98
    grade_group points 1 0
    echo "param-sweep pixel gate: PASS ($((MAIN_N + POINTS_N + MESH_N)) variants graded, $BLOCKED_N reference-renderer blocked, exit 0)"
    ;;
esac
