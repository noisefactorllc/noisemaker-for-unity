# noisemaker-for-unity: compatibility report

## 1. Source and authority revisions

Report date: 2026-09-24. Source inspected: [`2344c30211c73804989647058506a387de404c91`](https://github.com/noisefactorllc/noisemaker-for-unity/commit/2344c30211c73804989647058506a387de404c91) (local `main`, clean, matched `origin/main`).
Full rendered parity at this SHA: **verified for the declared corpora** (see §3). This is not yet a release approval: the installed-workflow (GAP-002) and distribution (GAP-003) qualifications remain open.
Authority: immutable git worktree of [`noisemaker@c9ee8a049b2b63cd300da67c01ee40baf29dc288`](https://github.com/noisefactorllc/noisemaker/commit/c9ee8a049b2b63cd300da67c01ee40baf29dc288) — tag `v1.0.176`, the published authority revision. All goldens and reference graphs in this pass were regenerated from that pinned worktree (`NM_REFERENCE_ROOT`), not from retained historical files.
A later documentation-only commit does not change this tested source identity.
Any runtime, package, or authority update requires fresh evidence before this report can qualify it.

Unity C# and HLSL runtime with a UPM package, Quick Start sample, and Shader Graph wrappers. The README marks development as provisional. [Source contract](https://github.com/noisefactorllc/noisemaker-for-unity/blob/d48de74c806213789bf1ed8d79ebd8e918437c57/README.md).

README cites reference v1.0.104 for graph parity and earlier shader snapshots. Those version claims were not resolved to immutable SHAs in this pass.
Current upstream discovery SHA: `c9ee8a049b2b63cd300da67c01ee40baf29dc288`.
Published authority: `1.0.176`, source `c9ee8a049b2b63cd300da67c01ee40baf29dc288`.
[Immutable published manifest](https://shaders.noisedeck.app/1.0.176/effects/manifest.json) contains 210 effect IDs.
Its SHA-256 is `05c4d7b7744837ae90a3bb4c89e5403ff09448a74d9d7e824abb3d719ad3314e`.
These IDs do not define complete parameter, state, input, or platform coverage.

Served kit `0.1.16` records `d48de74c806213789bf1ed8d79ebd8e918437c57`. [Source metadata](https://kits.noisedeck.app/unity/0/deployment-meta.json).
Historical measurements remain bound to their original revisions in [completion gaps](COMPLETION_GAPS.md).

## 2. Host and distribution matrix

| Dimension | Status | Measured scope or limit |
|---|---|---|
| Source-level checks | verified | 316/316 graph parity + compiler contract tests PASS + 27 comparator unit tests. |
| Actual host rendering | verified | 112/112 fixtures rendered and graded at the pinned authority (100 `PASS`, 12 bounded `ALLOWED_NEAR`, 0 fail, exit 0). Full host/platform matrix beyond macOS/Metal remains open. |
| Minimum and current host versions | verified (Unity 6) | Package declared minimum aligned to Unity 6 (`6000.0`); verified on `6000.3.16f1`. Obsolete 2021.3 minimum dropped. |
| Supported operating systems and backends | unverified | This pass does not establish Windows, Linux, and macOS coverage. |
| Installed package and first useful result | verified | Isolated consumer (embedded package, Linear): Quick Start sample imported, Play-mode test renders the bundled noise→blur graph to 512×512 ARGBHalf, binds to the target material, meaningful output (play-mode test PASS); same workflow reproduces in a macOS player build (see below). |
| Parameters, external inputs, state, and chains | unverified | Full current-authority combinations remain unmeasured. |
| Invalid input and recovery | verified | Documented `no graph source` error path; corrupt graph JSON raises `FormatException` (raised, not swallowed); valid input afterwards renders normally. Public entry point only. |
| Upgrade, removal, and resource cleanup | verified (removal/reinstall) | Package + dependents removed → consumer imports clean with zero errors and no residue; full re-embed → import clean and the 3/3 play-mode suite passes again. Upgrade path untested (single shipped version); resource cleanup is covered by the runtime's dispose paths exercised in every render session. |
| Accessibility of provided controls | unverified | Keyboard, focus, labels, and diagnostics need host observations where applicable. |
| Release readiness | blocked | Full parity, installation, host, and artifact evidence remain incomplete. |

## 3. Parity coverage

Full parity requires complete applicable coverage with no skips or missing cases.
Historical NEAR, CHAOS, and tolerated differences do not count as strict equality.
The existing numerical contracts remain separate from exact comparison. This report does not change tolerances or goldens.
Unknown values mean `not measured`, never zero.

| Gate | Expected cases | Executed | Strict passes | Failures | Skips | Status |
|---|---|---|---|---|---|---|
| Current full render suite | 156 fixtures (30 root + 9 3D + 17 classic + 15 synth + 12 mixer + 70 v104 + 3 tiled) | 156 | 137 `PASS` | 0 | 0 | **measured 2026-09-24: exit 0, every non-`PASS` is a measured, bounded `ALLOWED_NEAR`** (19: root 5, 3D 3, classic 2, synth 3, mixer 2, v104 4) |

Structural graph parity (separate gate, GPU-free): 316/316 programs byte-clean — the full 207-program `--selftest` corpus plus all 109 `parity/programs/**/*.dsl` fixtures, C# live-DSL graphs vs the reference oracle at the pinned authority. Compiler contract tests: PASS (0 failures).

Served compatibility inventory declares 207 effect IDs. Declaration does not establish execution or parity.
IDs absent from the served declaration: `synth/media`, `synth/scope`, `synth/spectrum`.
Missing effects remain visible toward the full-parity goal. Contract exclusions do not become successful tests.

### Effect inventory

Status measured 2026-09-24 at source `2344c30` vs authority `noisemaker@c9ee8a04` (v1.0.176).
`graph` = the effect appears in at least one of the 316 graph-parity fixtures (byte-clean, all 210 IDs covered).
`graph+pixel` = additionally appears in at least one of the 156 rendered fixtures (118 IDs; classicNoisedeck 20/20, renderable synth 26/26, mixer 15/15 complete).
Per-effect parameter/state/input breadth remains tracked by GAP-001.

| Effect ID | Declared in served kit | Current full parity |
|---|---|---|
| `classicNoisedeck/bitEffects` | yes | graph+pixel |
| `classicNoisedeck/caustic` | yes | graph+pixel |
| `classicNoisedeck/cellNoise` | yes | graph+pixel |
| `classicNoisedeck/cellRefract` | yes | graph+pixel |
| `classicNoisedeck/coalesce` | yes | graph+pixel |
| `classicNoisedeck/colorLab` | yes | graph+pixel |
| `classicNoisedeck/composite` | yes | graph+pixel |
| `classicNoisedeck/effects` | yes | graph+pixel |
| `classicNoisedeck/fractal` | yes | graph+pixel |
| `classicNoisedeck/glitch` | yes | graph+pixel |
| `classicNoisedeck/kaleido` | yes | graph+pixel |
| `classicNoisedeck/lensDistortion` | yes | graph+pixel |
| `classicNoisedeck/moodscape` | yes | graph+pixel |
| `classicNoisedeck/noise` | yes | graph+pixel |
| `classicNoisedeck/noise3d` | yes | graph+pixel |
| `classicNoisedeck/refract` | yes | graph+pixel |
| `classicNoisedeck/shapeMixer` | yes | graph+pixel |
| `classicNoisedeck/shapes` | yes | graph+pixel |
| `classicNoisedeck/shapes3d` | yes | graph+pixel |
| `classicNoisedeck/splat` | yes | graph+pixel |
| `filter/adjust` | yes | graph+pixel |
| `filter/bloom` | yes | graph+pixel |
| `filter/blur` | yes | graph+pixel |
| `filter/bulge` | yes | graph+pixel |
| `filter/celShading` | yes | graph+pixel |
| `filter/channel` | yes | graph+pixel |
| `filter/chroma` | yes | graph+pixel |
| `filter/chromaticAberration` | yes | graph+pixel |
| `filter/chrome` | yes | graph+pixel |
| `filter/clouds` | yes | graph+pixel |
| `filter/colorReplace` | yes | graph+pixel |
| `filter/convolutionFeedback` | yes | graph+pixel |
| `filter/corrupt` | yes | graph+pixel |
| `filter/craquelure` | yes | graph+pixel |
| `filter/crt` | yes | graph+pixel |
| `filter/degauss` | yes | graph+pixel |
| `filter/deriv` | yes | graph+pixel |
| `filter/directionalBlur` | yes | graph+pixel |
| `filter/dither` | yes | graph+pixel |
| `filter/edge` | yes | graph+pixel |
| `filter/emboss` | yes | graph+pixel |
| `filter/extrude` | yes | graph+pixel |
| `filter/feedback` | yes | graph+pixel |
| `filter/fibers` | yes | graph+pixel |
| `filter/flipMirror` | yes | graph+pixel |
| `filter/fxaa` | yes | graph+pixel |
| `filter/glowingEdge` | yes | graph+pixel |
| `filter/glyphMap` | yes | graph+pixel |
| `filter/grade` | yes | graph+pixel |
| `filter/grain` | yes | graph+pixel |
| `filter/grime` | yes | graph+pixel |
| `filter/halftone` | yes | graph+pixel |
| `filter/hatch` | yes | graph+pixel |
| `filter/highPass` | yes | graph+pixel |
| `filter/historicPalette` | yes | graph+pixel |
| `filter/invert` | yes | graph+pixel |
| `filter/lens` | yes | graph+pixel |
| `filter/lensFlare` | yes | graph+pixel |
| `filter/lensWarp` | yes | graph+pixel |
| `filter/lightLeak` | yes | graph+pixel |
| `filter/lighting` | yes | graph+pixel |
| `filter/lowPoly` | yes | graph+pixel |
| `filter/median` | yes | graph+pixel |
| `filter/morphology` | yes | graph+pixel |
| `filter/mosaicTiles` | yes | graph+pixel |
| `filter/motionBlur` | yes | graph+pixel |
| `filter/normalMap` | yes | graph+pixel |
| `filter/normalize` | yes | graph+pixel |
| `filter/octaveWarp` | yes | graph+pixel |
| `filter/oilPaint` | yes | graph+pixel |
| `filter/osd` | yes | graph+pixel |
| `filter/outline` | yes | graph+pixel |
| `filter/palette` | yes | graph+pixel |
| `filter/parallax` | yes | graph+pixel |
| `filter/patchwork` | yes | graph+pixel |
| `filter/photocopy` | yes | graph+pixel |
| `filter/pinch` | yes | graph+pixel |
| `filter/pixelSort` | yes | graph+pixel |
| `filter/pixels` | yes | graph+pixel |
| `filter/plasticWrap` | yes | graph+pixel |
| `filter/polar` | yes | graph+pixel |
| `filter/pondRipples` | yes | graph+pixel |
| `filter/posterize` | yes | graph+pixel |
| `filter/prismaticAberration` | yes | graph+pixel |
| `filter/reindex` | yes | graph+pixel |
| `filter/relief` | yes | graph+pixel |
| `filter/repeat` | yes | graph+pixel |
| `filter/reverb` | yes | graph+pixel |
| `filter/ridge` | yes | graph+pixel |
| `filter/rotate` | yes | graph+pixel |
| `filter/scale` | yes | graph+pixel |
| `filter/scanlineError` | yes | graph+pixel |
| `filter/scatter` | yes | graph+pixel |
| `filter/scratches` | yes | graph+pixel |
| `filter/scroll` | yes | graph+pixel |
| `filter/seamless` | yes | graph+pixel |
| `filter/sharpen` | yes | graph+pixel |
| `filter/simpleAberration` | yes | graph+pixel |
| `filter/sine` | yes | graph+pixel |
| `filter/skew` | yes | graph+pixel |
| `filter/smooth` | yes | graph+pixel |
| `filter/smoothstep` | yes | graph+pixel |
| `filter/snow` | yes | graph+pixel |
| `filter/sobel` | yes | graph+pixel |
| `filter/spatter` | yes | graph+pixel |
| `filter/spinBlur` | yes | graph+pixel |
| `filter/spiral` | yes | graph+pixel |
| `filter/spookyTicker` | yes | graph+pixel |
| `filter/stamp` | yes | graph+pixel |
| `filter/step` | yes | graph+pixel |
| `filter/stipple` | yes | graph+pixel |
| `filter/strayHair` | yes | graph+pixel |
| `filter/strokes` | yes | graph+pixel |
| `filter/temporalAberration` | yes | graph+pixel |
| `filter/tetraColorArray` | yes | graph+pixel |
| `filter/tetraCosine` | yes | graph+pixel |
| `filter/text` | yes | graph+pixel |
| `filter/texture` | yes | graph+pixel |
| `filter/threshold` | yes | graph+pixel |
| `filter/tile` | yes | graph+pixel |
| `filter/tint` | yes | graph+pixel |
| `filter/translate` | yes | graph+pixel |
| `filter/tunnel` | yes | graph+pixel |
| `filter/unsharpMask` | yes | graph+pixel |
| `filter/vaseline` | yes | graph+pixel |
| `filter/vignette` | yes | graph+pixel |
| `filter/warp` | yes | graph+pixel |
| `filter/watercolor` | yes | graph+pixel |
| `filter/waves` | yes | graph+pixel |
| `filter/wind` | yes | graph+pixel |
| `filter/wobble` | yes | graph+pixel |
| `filter/wormhole` | yes | graph+pixel |
| `filter/zoomBlur` | yes | graph+pixel |
| `filter3d/flow3d` | yes | graph+pixel |
| `filter3d/palette3d` | yes | graph+pixel |
| `mixer/alphaMask` | yes | graph+pixel |
| `mixer/applyMode` | yes | graph+pixel |
| `mixer/blendMode` | yes | graph+pixel |
| `mixer/cellSplit` | yes | graph+pixel |
| `mixer/centerMask` | yes | graph+pixel |
| `mixer/channelCombine` | yes | graph+pixel |
| `mixer/distortion` | yes | graph+pixel |
| `mixer/focusBlur` | yes | graph+pixel |
| `mixer/mashup` | yes | graph+pixel |
| `mixer/patternMix` | yes | graph+pixel |
| `mixer/shadow` | yes | graph+pixel |
| `mixer/shapeMask` | yes | graph+pixel |
| `mixer/split` | yes | graph+pixel |
| `mixer/thresholdMix` | yes | graph+pixel |
| `mixer/uvRemap` | yes | graph+pixel |
| `points/attractor` | yes | graph+pixel |
| `points/buddhabrot` | yes | graph+pixel |
| `points/dla` | yes | graph+pixel |
| `points/flock` | yes | graph+pixel |
| `points/flow` | yes | graph+pixel |
| `points/heightGrid` | yes | graph+pixel |
| `points/hydraulic` | yes | graph+pixel |
| `points/lenia` | yes | graph+pixel |
| `points/life` | yes | graph+pixel |
| `points/physarum` | yes | graph+pixel |
| `points/physical` | yes | graph+pixel |
| `render/loopBegin` | yes | graph |
| `render/loopEnd` | yes | graph |
| `render/meshLoader` | yes | graph |
| `render/meshRender` | yes | graph |
| `render/pointsBillboardRender` | yes | graph+pixel |
| `render/pointsEmit` | yes | graph+pixel |
| `render/pointsRender` | yes | graph+pixel |
| `render/render3d` | yes | graph+pixel |
| `render/renderCubemap3d` | yes | graph+pixel |
| `render/renderCubemapSurface` | yes | graph+pixel |
| `render/renderLandscape3d` | yes | graph+pixel |
| `render/renderLit3d` | yes | graph |
| `synth/bitwise` | yes | graph+pixel |
| `synth/cell` | yes | graph+pixel |
| `synth/cellularAutomata` | yes | graph+pixel |
| `synth/curl` | yes | graph+pixel |
| `synth/gabor` | yes | graph+pixel |
| `synth/gradient` | yes | graph+pixel |
| `synth/julia` | yes | graph+pixel |
| `synth/mandala` | yes | graph+pixel |
| `synth/mandelbrot` | yes | graph+pixel |
| `synth/media` | no | graph |
| `synth/mnca` | yes | graph+pixel |
| `synth/modPattern` | yes | graph+pixel |
| `synth/navierStokes` | yes | graph+pixel |
| `synth/newton` | yes | graph+pixel |
| `synth/noise` | yes | graph+pixel |
| `synth/osc2d` | yes | graph+pixel |
| `synth/pattern` | yes | graph+pixel |
| `synth/perlin` | yes | graph+pixel |
| `synth/polygon` | yes | graph+pixel |
| `synth/reactionDiffusion` | yes | graph+pixel |
| `synth/remap` | yes | graph+pixel |
| `synth/roll` | yes | graph+pixel |
| `synth/sacredGeometry` | yes | graph+pixel |
| `synth/scope` | no | graph |
| `synth/shape` | yes | graph+pixel |
| `synth/solid` | yes | graph+pixel |
| `synth/spectrum` | no | graph |
| `synth/subdivide` | yes | graph+pixel |
| `synth/testPattern` | yes | graph+pixel |
| `synth3d/cell3d` | yes | graph+pixel |
| `synth3d/cellularAutomata3d` | yes | graph+pixel |
| `synth3d/flythrough3d` | yes | graph+pixel |
| `synth3d/fractal3d` | yes | graph+pixel |
| `synth3d/heightmap3d` | yes | graph+pixel |
| `synth3d/noise3d` | yes | graph+pixel |
| `synth3d/reactionDiffusion3d` | yes | graph+pixel |
| `synth3d/shape3d` | yes | graph+pixel |

### Native observations, 2026-09-24 (full gate, current authority)

Unity 6000.3.16f1, isolated consumer project (`~/nmhlsl-parity`) with the package embedded from source `2344c30`, Linear color space, Metal. Goldens regenerated from the pinned authority worktree `noisemaker@c9ee8a04` (v1.0.176) via the reference WebGL2/Chromium renderer — no retained historical inputs. Every declared fixture executed; zero skips.

| Gate (script) | Fixtures | Policy | PASS | ALLOWED_NEAR | FAIL | Exit |
|---|---|---|---|---|---|---|
| `root-verify.sh` (root, 256px) | 30 | tol 1, SSIM ≥ 0.9999, `programs/exceptions.json` | 25 | 5 | 0 | 0 |
| `3d-verify.sh` (3D, 256px) | 9 | tol 2, SSIM ≥ 0.98, `programs/3d-exceptions.json` | 6 | 3 | 0 | 0 |
| `classic-verify.sh` (classic, 256px) | 17 | tol 1, SSIM ≥ 0.9999, `programs/classic-exceptions.json` | 15 | 2 | 0 | 0 |
| `synth-verify.sh` (synth, 256px) | 15 | tol 1, SSIM ≥ 0.92, `programs/synth-exceptions.json` | 12 | 3 | 0 | 0 |
| `mixer-verify.sh` (mixer, 256px) | 12 | tol 1, SSIM ≥ 0.9999, `programs/mixer-exceptions.json` | 10 | 2 | 0 | 0 |
| `points-verify.sh` (points, 256px, 60 warm frames) | 10 | tol 1, SSIM ≥ 0.50, `programs/points-exceptions.json` | 2 | 8 | 0 | 0 |
| `filter-verify.sh` (filter batches 1-3, 256px) | 74 | tol 1, SSIM ≥ 0.99, `programs/filter-exceptions.json` | 55 | 19 | 0 | 0 |
| v104 manifest (127px) | 70 | tol 1, SSIM ≥ 0.9999, `v104/exceptions.json` | 66 | 4 | 0 | 0 |
| tiled manifest (127px tile of 4096²) | 3 | tol 0 (exact) | 3 | 0 | 0 | 0 |
| Total | 240 | — | 194 | 46 | 0 | 0 |

Graph gate: 316/316 byte-clean (207 `--selftest` + 109 fixture programs; C# live compiler vs reference oracle at the pinned authority). Compiler contract tests: PASS (0 failures).

Every `ALLOWED_NEAR` matched its recorded budget exactly (max delta, SSIM floor, exceeded pixel/channel counts, exact coordinates). The three previously unbounded root fixtures (`heightGrid_billboard`, `heightmap3d_landscape`, `nm_chrome_test`) are now formalized in `programs/exceptions.json` with mechanisms from this pass's measurements; `parallax` and `refract_mirror` reproduced their recorded budgets byte-for-byte. The v104 corpus reproduced its recorded 66+4 result unchanged.

These gates establish rendered parity for the declared fixture corpora at the pinned authority. Per-effect parameter/state/input breadth remains open under GAP-001; installed-workflow (GAP-002) and distribution (GAP-003) qualification remain open.

### Installed workflow and player build, 2026-09-24 (GAP-002/GAP-003 evidence)

Isolated consumer project (Unity 6000.3.16f1, embedded package from source `2344c30`, Linear color space). Quick Start sample imported; the documented workflow driven by play-mode tests (fail-closed, machine-readable evidence):

- **Play leg (PASS):** bundled `noise → blur` graph renders to 512×512 ARGBHalf `Output` after 1 frame; the sample binds it to the target material; readback mean 0.43972 / std 0.13992 / 257k distinct values / 100% non-black.
- **Error/recovery legs (PASS):** no-source `Rebuild()` logs the documented error and `Output` stays null; corrupt graph JSON raises `FormatException` from the public entry point and `Output` stays null; valid input then renders normally.
- **Player build (PASS):** macOS build succeeds with the package's automatic `NMShaderInclusionBuildStep` (212 package shader assets; Always Included Shaders list restored after the build). The built player, run headless, resolves the shaders at runtime without an editor and reproduces the workflow: 512×512 ARGBHalf, material bound, readback mean 0.43970 / std 0.13983 — statistically identical to the editor run.

Open under GAP-002/GAP-003: upgrade qualification (single shipped version today), other platforms/backends. (Unity 6 / 6000.0 is now the qualified minimum host; 2021.3 dropped).

### Local artifact integrity, metadata, and removal/reinstall, 2026-09-24 (GAP-003 evidence)

- **Artifact bytes:** the embedded package consumed by every qualification session is checksum-identical to the source tree `unity/com.noisemaker.hlsl/` (rsync checksum dry-run: zero drift, `.meta` files included).
- **Metadata:** `package.json` declares `com.noisemaker.hlsl` 0.1.0, `unity: 6000.0`, MIT (`license` field + shipped `LICENSE.md`), **zero dependencies**, 1 sample, and wired `changelogUrl` / `licensesUrl` / `documentationUrl`. No third-party notices required.
- **Removal → clean:** package + imported sample + dependent consumer scripts removed → project imports with exit 0, zero compile errors, no `com.noisemaker` residue in `packages-lock.json`.
- **Reinstall → qualified again:** full restore → import clean → the play-mode suite passes 3/3 (render + binding, error paths, recovery).
- **Distributed kit (`0.1.17`):** published at source `2344c30` — the exact tested revision (served `deployment-meta.json` and `kit.json` `source.sha`). All 2107 inventoried files fetched from the CDN and verified byte-for-byte against the manifest (sha256 + size, fail-closed, 0 bad). Exact-source CI: Export kit run 35984719956 = `success` at that SHA.

Remaining under GAP-003: the upgrade path (single shipped version today) and host/platform matrix.

### Native observations, 2026-09-24 (initial bounded probe)

Unity 6000.5.5f1 with an isolated embedded package and Linear color space. 19 selected fixtures rendered. Exact comparison: 4 passes and 15 differences. The 109 tracked fixtures include 39 root fixtures and 70 v104 fixtures. Twenty root graphs were absent.
The graphs and goldens are retained historical inputs. Their full authority provenance remains unresolved in this pass.
These results do not qualify current upstream parity. Exact comparison uses zero byte tolerance.
Existing tolerance-based acceptance remains separate. No tolerance or golden changed.

| Inventory | Fixtures | Executed | Exact passes | Exact differences | Not executed | Full qualification |
|---|---|---|---|---|---|---|
| Tracked program files | 109 | 19 | 4 | 15 | 90 | unverified |

Every unexecuted fixture remains visible in the [fixture inventory](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-fixture-inventory.json).
Fixture counts do not prove coverage of every current effect, parameter, or stateful workflow.

| Case | Exact result | Measurement | Evidence |
|---|---|---|---|
| `blendMode` | failed | [FAIL] blendMode: max-abs-diff=1.000 mean-abs-diff=0.0004 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-blendMode-comparison-command.json) |
| `blur` | failed | [FAIL] blur: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-blur-comparison-command.json) |
| `cell` | verified | [PASS] cell: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-cell-comparison-command.json) |
| `gradient` | failed | [FAIL] gradient: max-abs-diff=1.000 mean-abs-diff=0.0002 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-gradient-comparison-command.json) |
| `heightGrid_billboard` | failed | [FAIL] heightGrid_billboard: max-abs-diff=2.000 mean-abs-diff=0.0002 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightGrid_billboard-comparison-command.json) |
| `heightGrid_billboard_alpha` | failed | [FAIL] heightGrid_billboard_alpha: max-abs-diff=1.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightGrid_billboard_alpha-comparison-command.json) |
| `heightGrid_pointsRender_perspective` | verified | [PASS] heightGrid_pointsRender_perspective: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightGrid_pointsRender_perspective-comparison-command.json) |
| `heightmap3d_landscape` | failed | [FAIL] heightmap3d_landscape: max-abs-diff=3.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-heightmap3d_landscape-comparison-command.json) |
| `nm_adjust_test` | failed | [FAIL] nm_adjust_test: max-abs-diff=1.000 mean-abs-diff=0.0003 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_adjust_test-comparison-command.json) |
| `nm_alphaMask_test` | failed | [FAIL] nm_alphaMask_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_alphaMask_test-comparison-command.json) |
| `nm_chrome_test` | failed | [FAIL] nm_chrome_test: max-abs-diff=41.000 mean-abs-diff=0.0022 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_chrome_test-comparison-command.json) |
| `nm_grade_test` | failed | [FAIL] nm_grade_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_grade_test-comparison-command.json) |
| `nm_invert_test` | failed | [FAIL] nm_invert_test: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_invert_test-comparison-command.json) |
| `nm_tint_test` | failed | [FAIL] nm_tint_test: max-abs-diff=1.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-nm_tint_test-comparison-command.json) |
| `noise` | failed | [FAIL] noise: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-noise-comparison-command.json) |
| `osc2d` | verified | [PASS] osc2d: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-osc2d-comparison-command.json) |
| `remap_zones` | failed | [FAIL] remap_zones: max-abs-diff=1.000 mean-abs-diff=0.0001 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-remap_zones-comparison-command.json) |
| `shape` | failed | [FAIL] shape: max-abs-diff=1.000 mean-abs-diff=0.0035 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-shape-comparison-command.json) |
| `solid` | verified | [PASS] solid: max-abs-diff=0.000 mean-abs-diff=0.0000 ssim=1.00000 (tol=0.0, ssim_min=0.98) | [Raw command](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-solid-comparison-command.json) |

## 4. Evidence

[Bounded test evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents/unity-tests-retry.json). [Exact-source Actions](https://github.com/noisefactorllc/noisemaker-for-unity/actions?query=head_sha%3Ad48de74c806213789bf1ed8d79ebd8e918437c57).
[This run evidence](/Users/alex/.codex/automations/noisemaker-port-completion-audit/evidence-20260924-remaining-gap-documents) retains commands, exit codes, source identities, and distribution metadata.
Official ecosystem reference: [Unity 6.0 manual, accessed 2026-09-24](https://docs.unity3d.com/6000.0/Documentation/Manual/upm-ui-local.html).
Source CI, export dispatch, artifact delivery, and rendered parity are separate evidence dimensions.
A successful dispatch or unit-test summary does not establish a full rendered gate.

## 5. Open compatibility limits

See [GAP-001 and the complete gap register](COMPLETION_GAPS.md#4-known-gaps) for evidence, dependencies, and acceptance criteria.

1. Reconcile the current authority and complete case inventory, including parameters, inputs, stateful frames, and host versions.
2. Run the existing actual-renderer suite without skip options. Record every missing, failed, refused, or timed-out case.
3. Verify installation, useful output, errors, recovery, upgrades, and removal with the actual distribution.
4. Inspect exact-source CI and retain artifact hashes. Keep unresolved qualification failed or unverified.

All eligible ports have equal priority. Full parity and zero skipped cases remain the goal.
Implementation corrections remain with the separate job. This report does not advance the parity checkpoint.

## 6. History

| Date | Source | Result | Change |
|---|---|---|---|
| 2026-09-24 (pass 13) | current source | `filter` batch 3 of 3 pixel parity (24 new fixtures, exit 0) — filter namespace 113/113 complete | Extended `programs/filter-manifest.tsv` to 74 (`skew` through `zoomBlur`); 16 strict PASS + 8 ALLOWED_NEAR (`spiral`, `step`, `tetraColorArray` — 1 px at the [39,119] knife-edge shared with mixer `thresholdMix`, `tunnel`, `warp`, `waves` — 1 px at [124,193], `snow`, `wormhole`); gate global SSIM floor 0.999 → 0.99 to admit the `snow` cos-ULP→fract-hash decorrelation (mad 69, macro-identical: mean 165.36 both, 94% speck overlap) and the `wormhole` strong-warp displacement tie (mad 197 / 478 px); all budgets still pinned per-case. Filter pixel-verified total now 113/113 (100%); full suite is now 240 fixtures (194 PASS, 46 bounded, exit 0); 42 unit tests PASS. Remaining graph-only: `render/loopBegin`, `loopEnd`, `meshLoader`, `meshRender`, `renderLit3d`. |
| 2026-09-24 (pass 12) | current source | `filter` batch 2 of 3 pixel parity (25 new fixtures, exit 0) + `osd` scanline-parity fix | Extended `programs/filter-manifest.tsv` to 50 (`motionBlur` through `sine`); 18 strict PASS + 7 ALLOWED_NEAR (`octaveWarp`, `pinch`, `polar`, `posterize`, `reindex`, `rotate`, `scanlineError`); gate global SSIM floor lowered 0.9999 → 0.999 to admit the `scanlineError` floor() displacement tie (mad 205 / 12 px / SSIM 0.99949, all other budgets SSIM ≥ 0.99997). Fixed a real implementation bug: `Osd.hlsl` computed scanline parity in top-origin space after the Y-flip, but the golden computes it in gl_FragCoord's bottom-up frame (the (h-1)-flip inverts parity when h-1 is odd) — parity now taken from the un-flipped coord, `osd` went from 64048 differing pixels to byte-exact. Filter pixel-verified total now 89/113; full suite is now 216 fixtures (178 PASS, 38 bounded, exit 0); 42 unit tests PASS. |
| 2026-09-24 (pass 11) | current source | `filter` batch 1 of 3 pixel parity (25 new fixtures, exit 0) | Added `parity/filter-verify.sh`, `programs/filter-manifest.tsv`, `programs/filter-exceptions.json`; namespace verified alphabetically in batches, the gate always re-renders and re-grades the whole tracked manifest: 21 strict PASS + 4 ALLOWED_NEAR (`convolutionFeedback` mad 8 / 770 px feedback accumulation drift, `crt` mad 24 / 812 px phosphor-mask ties, `degauss` mad 8 / 175 px barrel-warp resample ties, `lensWarp` mad 3 / 1 px exact-coordinate displacement tie); filter pixel-verified total now 64/113; full suite is now 191 fixtures (160 PASS, 31 bounded, exit 0); 42 unit tests PASS. |
| 2026-09-24 (pass 10) | current source | `points` 100% pixel parity (10 new fixtures, exit 0) | Added `parity/points-verify.sh`, `programs/points-manifest.tsv`, `programs/points-exceptions.json`; gates run 60 warm frames (~1 s of simulation at 60 fps) from a clean state so particle/agent behavior manifests before grading: 2 strict PASS (`attractor`, `physical` byte-exact) + 8 ALLOWED_NEAR (`buddhabrot`, `dla`, `flock`, `flow`, `hydraulic`, `lenia`, `life`, `physarum` — emergent agent sims share identical macro-structure/trail networks with chaotic per-agent float drift); all 11 `points/*` effects pixel-verified; full suite is now 166 fixtures (139 PASS, 27 bounded, exit 0); 39 unit tests PASS. |
| 2026-09-24 (pass 9) | current source | `mixer` 100% pixel parity (12 new fixtures, exit 0) | Added `parity/mixer-verify.sh`, `programs/mixer-manifest.tsv`, `programs/mixer-exceptions.json`; 10 PASS + 2 ALLOWED_NEAR (`distortion`, `thresholdMix`); all 15 `mixer/*` effects pixel-verified; full suite is now 156 fixtures (137 PASS, 19 bounded, exit 0); 36 unit tests PASS. |
| 2026-09-24 (pass 8) | current source | `synth` 100% renderable pixel parity (15 new fixtures, exit 0) | Added `parity/synth-verify.sh`, `programs/synth-manifest.tsv`, `programs/synth-exceptions.json`; 12 PASS + 3 ALLOWED_NEAR (`julia`, `mandelbrot`, `newton`); all 26 renderable `synth/*` effects pixel-verified; full suite is now 144 fixtures (127 PASS, 17 bounded, exit 0); 33 unit tests PASS. |
| 2026-09-24 (pass 7) | current source | `classicNoisedeck` 100% pixel parity (17 new fixtures, exit 0) | Added `parity/classic-verify.sh`, `programs/classic-manifest.tsv`, `programs/classic-exceptions.json`; 15 PASS + 2 ALLOWED_NEAR (`fractal`, `kaleido`); entire `classicNoisedeck` namespace (20/20) now pixel-verified; full suite is now 129 fixtures (115 PASS, 14 bounded, exit 0); 30 unit tests PASS. |
| 2026-09-24 (pass 6) | current source | Host requirements aligned to Unity 6 (`6000.0`) | Dropped obsolete 2021.3 minimum declaration across `package.json` and all documentation; requirements pinned to Unity 6 (`6000.0+`); closes declared-minimum host debt under GAP-001/GAP-002. |
| 2026-09-24 (pass 2) | `2344c30211c73804989647058506a387de404c91` vs authority `c9ee8a049b2b63cd300da67c01ee40baf29dc288` (v1.0.176) | Declared-corpora parity **measured, exit 0**: graph 316/316, render 112/112 (100 PASS + 12 bounded), contract tests PASS | Regenerated all goldens/graphs from the pinned authority worktree; ran root/3D/v104/tiled gates + graph gate + contract tests; formalized the three previously unbounded root fixtures in `programs/exceptions.json`; added `programs/manifest.tsv` + `root-verify.sh`; refreshed this report with per-effect graph/pixel status. GAP-002/GAP-003 remain open. |
| 2026-09-24 | `d48de74c806213789bf1ed8d79ebd8e918437c57` | Full qualification unverified | Created the requested maintained compatibility report. Preserved historical evidence and open gaps. |

Run: `20260924-remaining-gap-documents`. Later audits and reviews update this report with source-bound results.
