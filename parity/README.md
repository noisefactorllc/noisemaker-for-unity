# noisemaker-hlsl — Parity Harness

End-to-end pixel-parity verification: render the same DSL program with the **JS
reference engine** (golden) and the **Unity/HLSL port** (candidate), then diff.

This is how every ported piece gets validated — the package is built
correct-by-construction and is not pixel-verified until this harness runs (see
`../ARCHITECTURE.md` → "Validation").

```
  DSL ─┬─► tools/export-graph.mjs ───────────► graph.json ─┐
       │                                                    ├─► NMParityRunner.cs ─► candidate.png ─┐
       └─► parity/export-and-render.mjs ─► golden.png ──────┘ (Unity, batchmode)                    ├─► compare.py ─► PASS/FAIL
                              (reference GPU, Playwright)                                            │
                                                                          golden.png ───────────────┘
```

## Prerequisites

- **Node** (for `tools/` and `parity/*.mjs`). No `npm install` needed — the
  scripts import the sibling reference engine (`../../noisemaker/shaders`,
  `../../noisemaker/demo`) as plain ESM and the PNG encoder uses Node's built-in `zlib`.
- **Playwright + a system Chrome.** `export-and-render.mjs` launches Chromium via
  the vendored `shade-mcp` harness (`../../vendor/shade-mcp/harness`). On macOS it
  uses ANGLE/Metal; headless by default (`SHADE_HEADLESS=1`).
- **Python 3** with `numpy` + `pillow` (for `compare.py`) — same deps as
  `../../scripts/image_regression.py`.
- **A Unity project** (2021.3+, **Linear color space**) that includes the package
  `com.noisemaker.hlsl`.

All scripts honor `NM_REFERENCE_ROOT` to relocate the reference repo root
(default: two levels above `tools/`).

## Test programs

`programs/*.dsl` — 20 programs (8 Tier-1 + 4 3D/mixer + 8 targeting the v1.0.98 sync),
each with a fixed `seed: 1` so output is deterministic:

| file | effect | shape |
|---|---|---|
| `solid.dsl`     | `synth/solid`    | single-pass color fill |
| `noise.dsl`     | `synth/noise`    | single-pass value/simplex noise |
| `cell.dsl`      | `synth/cell`     | single-pass cellular/Voronoi |
| `gradient.dsl`  | `synth/gradient` | single-pass gradient |
| `shape.dsl`     | `synth/shape`    | single-pass SDF shape |
| `osc2d.dsl`     | `synth/osc2d`    | single-pass oscillator |
| `blur.dsl`      | `filter/blur`    | multi-pass H/V separable blur over noise |
| `blendMode.dsl` | `mixer/blendMode`| two-surface blend (o0 → o1) |
| `palette3d.dsl` | `filter3d/palette3d` | recolor a 3D volume by palette, viewed via render3d |
| `mashup.dsl` | `mixer/mashup` | luminance-band router (incl. active-when-wired fallback) |
| `renderCubemap3d.dsl` | `render/renderCubemap3d` | lit cubemap-face volume render (single face) |
| `renderCubemapSurface.dsl` | `render/renderCubemapSurface` | raw emission/absorption cubemap face |
| `lighting.dsl`   | `filter/lighting` | Sobel-normal lighting, self height map |
| `lighting_hm.dsl`| `filter/lighting` | explicit `heightMap:` surface lighting a gradient |
| `parallax.dsl`   | `filter/parallax` | parallax occlusion, self height map |
| `parallax_hm.dsl`| `filter/parallax` | explicit `heightMap:` surface, pivot 0.5 |
| `refract_mirror.dsl` | `classicNoisedeck/refract` | mirror wrap at amount 100 (seam-heavy) |
| `cellRefract_mirror.dsl` | `classicNoisedeck/cellRefract` | mirror wrap at amount 100 |
| `simpleAberration.dsl` | `filter/simpleAberration` | RGB split (unflipped Y, post-cee90aaf) |
| `remap_zones.dsl` | `synth/remap` | polygon zone router, wired zone (64-vert layout) |

### v1.0.104 artistic corpus

`programs/v104/` adds 70 deterministic programs for the v1.0.104 artistic-effects
sync. Run them at the parity size of 127x127. Filter cases use `synth/testPattern`
inputs; the Mandala and Sacred Geometry cases feed those generators into Parallax
over a `testPattern` surface. Every seed-bearing effect pins `seed: 1`.

The corpus covers all 25 new filters and the changed Dither, Edge, Emboss, Invert,
Low Poly, Texture, Parallax, Mandala, and Sacred Geometry paths. Focused programs
separate every disjoint branch required by the sync, including the ten new Texture
modes, all Median radii, mono Halftone patterns, zero-vector/zero-strength
passthroughs, and the large-radius blur paths. `programs/v104/manifest.tsv` lists
each program exactly once as `<name><TAB><repo-relative-dsl-path>` and is accepted
directly by the batch golden renderer. Two focused generator cases preserve
`speed: -1.5` through both graph compilers and cover Mandala/Sacred Geometry's
negative-fractional animation-speed runtime behavior:

```bash
NM_REFERENCE_ROOT=/path/to/noisemaker \
node parity/batch-golden.mjs parity/programs/v104/manifest.tsv parity/out/v104 \
  --size 127 --time 0.25 --backend webgl2
```

`programs/v104/tiled-manifest.tsv` reuses the Mandala, Sacred Geometry, and
Parallax cases for a focused nonzero-tile gate. The 4096px full frame makes
`fullResolution` differ from the 127px tile and activates Parallax's 256px
displacement clamp:

```bash
node parity/batch-golden.mjs parity/programs/v104/tiled-manifest.tsv /tmp/v104-tiled-golden \
  --size 127 --time 0.25 --backend webgl2 \
  --tile-x 1536 --tile-y 2048 --full-width 4096 --full-height 4096 --render-scale 1

"$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderBatchFromCommandLine \
  -nmManifest /tmp/v104-tiled-render.tsv -nmSize 127 -nmTime 0.25 \
  -nmTileX 1536 -nmTileY 2048 -nmFullWidth 4096 -nmFullHeight 4096 -nmRenderScale 1
```

This corpus was the pre-port RED gate: new filters were initially unknown and
changed definitions diverged on their new parameters and enum choices. The
definitions are now synchronized and all 70 cases are structurally byte-clean;
the complete shader/pixel result is recorded by the v1.0.104 verification run.

Pixel status: the 70-case v1.0.104 gate reports 66 `PASS` and 4 narrowly bounded
`ALLOWED_NEAR`; the two negative-fractional speed cases are strict passes. The
original 20-case regression reports 18 `PASS` and the established `parallax` /
`refract_mirror` exceptions. Every exception is checked against a per-case maximum
delta, SSIM floor, exceeded-pixel/channel counts, and exact top-left-origin pixel
coordinates where declared.

## Runbook

```bash
# 0. (once / when JS definitions change) regenerate ALL Unity effect-definition
#    JSON from the reference definitions. Supersedes the hand-written Tier-1 JSON.
node tools/convert-definitions.mjs            # writes unity/.../Effects/<ns>/<func>.json

# 1. Export golden PNG + normalized graph.json for one program.
#    Fixed: 256x256, normalized time 0.25, seed baked into the DSL.
node parity/export-and-render.mjs parity/programs/noise.dsl parity/out \
     --size 256 --time 0.25 --backend webgl2
#    -> parity/out/noise.golden.png  and  parity/out/noise.graph.json

# 2. Render the Unity candidate from the SAME graph.json (batchmode).
"$UNITY" -batchmode -quit -projectPath "$UNITY_PROJECT" \
  -executeMethod Noisemaker.Hlsl.Editor.NMParityRunner.RenderFromCommandLine \
  -nmGraph "$PWD/parity/out/noise.graph.json" \
  -nmOut   "$PWD/parity/out/noise.candidate.png" \
  -nmSize 256 -nmTime 0.25
#    (Editor menu equivalent: Noisemaker ▸ Parity ▸ Render Graph To PNG…)

# 3. Diff. Per-program tolerance; loosen --tolerance for stochastic/feedback effects.
python parity/compare.py \
  parity/out/noise.golden.png parity/out/noise.candidate.png \
  --name synth/noise --tolerance 2 --ssim-min 0.98 \
  --report parity/out/noise.report.json
#    exit 0 = within tolerance, 1 = divergence.
```

Loop over all programs with a shell `for` over `parity/programs/*.dsl`.

For a batch, `batch-compare.py` is fail closed: an empty corpus or any `NEAR`,
`FAIL`, missing image, or size mismatch returns nonzero. Repository-owned exception
files may promote only explicitly named, globally high-SSIM `NEAR` results whose
complete bounds match:

```bash
python3 parity/batch-compare.py /tmp/v104-golden /tmp/v104-candidate \
  --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/v104/exceptions.json \
  --out /tmp/v104-report.json

python3 parity/batch-compare.py /tmp/original-golden /tmp/original-candidate \
  --tolerance 1 --ssim-min 0.9999 \
  --exceptions parity/programs/exceptions.json
```

Exit 0 means every compared case is `PASS` or `ALLOWED_NEAR`. `FAIL`, missing,
mismatched, and empty runs cannot be allowlisted.

## Graph parity (live-DSL compiler)

The pixel harness above validates the *shaders + executor* from a precompiled graph. A
second, **GPU-free** harness validates the **C# live DSL compiler** (`Compiler/`) by
diffing the graph it produces against the reference `export-graph.mjs` oracle, byte-for-byte:

```
  DSL ─┬─ tools/export-graph.mjs ─────────────────────► <name>.ref.graph.json ─┐
       └─ NMParityRunner.CompileDslDumpBatchFromCommandLine (Unity, 1 session)  ├─► graph-diff.py ─► PASS/FAIL
                                                          <name>.cs.graph.json ─┘
```

Run it (one Unity session for all programs; no rendering):

```bash
UNITY=/path/to/Unity UNITY_PROJECT=/path/to/proj ./parity/graph-verify.sh         # all programs
UNITY=... UNITY_PROJECT=... ./parity/graph-verify.sh noise mashup                 # a subset
```

**No Unity needed:** the `Compiler/` assembly is pure C#, so `tools/graphdump/` builds
the same dump path as a .NET 8 console app:

```bash
dotnet build -c Release tools/graphdump
# manifest lines: <dslPath>\t<outPath>
dotnet tools/graphdump/bin/Release/net8.0/graphdump.dll \
  unity/com.noisemaker.hlsl/Effects manifest.tsv
python3 parity/graph-diff.py <name>.ref.graph.json <name>.cs.graph.json
```

`graph-diff.py` compares the normalized graphs structurally, ignoring the per-instance
`id` hash and `source`; a clean run is `0 deltas`. **v1.0.104 status: 304/304 programs
byte-clean** — the full 207-program `--selftest` corpus, all 90
`parity/programs/**/*.dsl` cases (including 70 v1.0.104 cases), and 7 targeted
variants (lighting/parallax heightMap explicit surface / mid-chain; remap default +
wired zones; a pointsBillboardRender particle pipeline), all identical to the
reference oracle via the console harness. The current demo generator also reports
three expected selector skips for the hidden deprecated aliases `filter/bc`,
`filter/colorspace`, and `filter/hs`; no defaults are fabricated for them. This is
the "diffed against the golden path" validation the live-DSL path was always meant
to have.

## Parity hazards (must match between golden and candidate)

- **Color space and format** — RTs use `RenderTextureReadWrite.Linear`; **never
  sRGB**. Their physical format follows each definition: `rgba8unorm` maps to
  `ARGB32`, while `rgba16f` maps to `ARGBHalf`. Both renderers quantise the final
  linear float readback with no gamma. Unity project must be Linear.
- **Y orientation** — the JS golden flips GL bottom-left origin to top-down PNG
  rows; Unity's `ReadPixels` is already top-down. Directional parity cases verify
  `NMBlit` / the runner as the single general reconciliation point. Texture's
  runtime and Shader Graph paths have distinct, separately verified source-UV
  conventions; do not copy a flip between them without focused pixel evidence.
- **Premultiplied alpha** — the WebGPU reference present path is premultiplied
  (`reference/04 §7`); match it if rendering the golden with `--backend webgpu`.
- **Determinism** — seed is in the DSL; time is pinned (paused). Both sides render
  8 frames at the pinned normalized time so feedback/state surfaces settle.

## Files

- `export-and-render.mjs` — golden renderer (graph.json + golden.png).
- `compare.py` — max-abs-diff + global SSIM gate, JSON report (pixel parity).
- `graph-verify.sh` — graph-parity harness (all programs: C# live graph vs the oracle).
- `graph-diff.py` — structural graph diff (ignores the `id` hash + `source`).
- `programs/*.dsl` — fixed-seed test programs (pixel + graph parity).
- `../unity/com.noisemaker.hlsl/Editor/NMParityRunner.cs` — Unity candidate renderer + `CompileDslDumpBatchFromCommandLine` (graph dumper).
- `../tools/export-graph.mjs` — golden graph producer (used by both harnesses).
- `../tools/convert-definitions.mjs` — effect-definition regenerator (step 0).
